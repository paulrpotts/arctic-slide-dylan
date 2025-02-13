Module: arctic-slide-od-app

// Experimental gameplay from the Polar Macintosh game by Go Endo
// This is a personal project I wrote to study object-oriented
// design using generic functions and multiple dispatch, aka
// "multimethods." https://en.wikipedia.org/wiki/Multiple_dispatch

// For an explanation of my design, see:
// https://thepottshouse.org/paul/portfolio/The_Polar_Game_in_Dylan.html

// Formatting notes: this code is formatted so that I could paste
// it into preformatted code blocks in Blogger blog posts. I have
// been migrating all my work out of Blogger and putting it in my
// own web archive, but my own web page style sheets still impose
// limitations on the width of code that works properly in HTML or
// For reference here are guides for 67 and 80 columns:
//
//34567890123456789012345678901234567890123456789012345678901234567
//345678901234567890123456789012345678901234567890123456789012345678901234567890

define constant $board-dim-y = 4;
define constant $board-dim-x = 24;
define constant $polar-level-1 =
    "100000000000000100000400"
    "106020545000000000100100"
    "100000000000000050002300"
    "110000100000000000000000";

define constant <dir> = one-of( #"north",
                                #"east",
                                #"south",
                                #"west" );

define class <pos> (<object>)
    constant slot y-idx :: <integer>, required-init-keyword: y-idx:;
    constant slot x-idx :: <integer>, required-init-keyword: x-idx:;
end class <pos>;

define constant <pos-or-false> = type-union( <pos>, singleton( #f ) );

define abstract class <tile> ( <object> ) end;
define abstract class <blocking> ( <tile> ) end;
define abstract class <walkable> ( <tile> ) end;
define abstract class <movable> ( <blocking> ) end;
define abstract class <fixed> ( <blocking> ) end;

// Tile classes. They have no state and are used
// solely for their types.

// <edge> does not actually appear on the board
// but is used internally as another <fixed> class
// to stop penguin and objects from moving past
// the edges of the board.

// <bomb> can be pushed and has special collision
// behavior with <mountain>.

// <heart> can be pushed and has special collision
// behavior with <house>.

// <ice-block> will disintegrate if pushed against
// any non-empty tile -- but not when slid, which
// requires some special handling.

// The penguin avatar can walk on <tree> tiles but
// they block all other moving objects, hence
// the dual inheritance.
define class <bomb> ( <movable> ) end;
define class <heart> ( <movable> ) end;
define class <ice-block> ( <movable> ) end;
define class <house> ( <fixed> ) end;
define class <mountain> ( <fixed> ) end;
define class <edge> ( <fixed> ) end;
define class <tree> ( <blocking>, <walkable> ) end;
define class <empty> ( <walkable> ) end;

// Singletons we use to populate the board array;
// this allows us to change tile behavior on the
// fly without creating or deleting objects, just
// changing references to singleton instances.
define constant $the-bomb = make( <bomb> );
define constant $the-empty = make( <empty> );
define constant $the-heart = make( <heart> );
define constant $the-house = make( <house> );
define constant $the-ice-block = make( <ice-block> );
define constant $the-mountain = make( <mountain> );
define constant $the-tree = make( <tree> );
define constant $the-edge = make( <edge> );

// We use this disjoint set of classes for defining
// the parameters of the collide and slide generics
define constant <blocking-or-empty> = type-union( <blocking>, <empty> );

define class <model> ( <object> )
    slot board :: <array>;
    slot penguin-pos :: <pos>;
    slot penguin-dir :: <dir>;
    slot heart-count :: <integer>;
end;

// slide handles movable tiles moving, updating the board
// as they go. For any movable tile and empty tile, we move
// the piece and call slide again. For the generic movable
// tile and any other tile case, we call collide, because
// the interaction of bomb/mountain and heart/house are the
// same whether it is the result of a direct push or takes
// place after a slide. slide for an ice block is a special
// case: the ice block is not destroyed after a slide, it
// just stops.
// Dispatch for slide depends on two class types and so
// we rely on the compiler to work out the specificity.
define generic slide( model :: <model>, dir :: <dir>,
    movable-pos :: <pos>, movable-tile :: <movable>,
    next-pos :: <pos-or-false>, next-tile :: <blocking-or-empty> );

// A <movable> tile interacting with an <empty> tile --
// move forward on the board and call slide again.
define method slide( model :: <model>, dir :: <dir>,
    movable-pos :: <pos>, movable-tile :: <movable>,
    next-pos :: <pos>, next-tile :: <empty> )
    format-out( "slide: movable / empty\n" );
    force-out();
    let next-next-pos :: <pos-or-false> =
        getAdjacentPos( next-pos, dir );
    let next-next-tile = getTileAtPos( model, next-next-pos );
    setTileAtPos( model, next-pos, movable-tile );
    setTileAtPos( model, movable-pos, $the-empty );
    slide( model, dir, next-pos, movable-tile,
           next-next-pos, next-next-tile );
end;

// A <movable> tile meets a <blocking> tile: call collide to
// handle heart/house, bomb/mountain, edge of world, etc.
define method slide( model :: <model>, dir :: <dir>,
    movable-pos :: <pos>, movable-tile :: <movable>,
    next-pos :: <pos-or-false>, next-tile :: <blocking> )
    format-out( "slide: movable / blocking, calling collide\n" );
    force-out();
    collide( model, dir, movable-pos, movable-tile,
              next-pos, next-tile );
end;

// A more specific <movable> tile, <ice-block>, meets a
// <blocking> tile; don't call collide since the behavior
// of a sliding ice block is different than a pushed ice
// block. It just stops.
define method slide( model :: <model>, dir :: <dir>,
    ice-block-pos :: <pos>, ice-block-tile :: <ice-block>,
    next-pos :: <pos-or-false>, next-tile :: <blocking> )
    format-out( "slide: ice block / blocking\n" );
    force-out();
end;

// collide handles interactions between pushed or
// sliding tiles: pushing a movable tile onto an empty
// tile will start it sliding. Pushing an ice block into
// any non-empty tile destroys it; pushing a bomb into
// a mountain blows up bomb and mountain; pushing a
// heart into a house removes the heart and gets us
// closer to our board completion condition. Our methods
// in the collidge GF are specialized on two parameters
// which makes it dependent on how smart the runtime
// dispatch is. I can show that all the cases ought to
// be clearly distinguishable on paper if I rank the
// matches by specificity, but I'm not sure the runtime
// will agree.
define generic collide( model :: <model>, dir :: <dir>,
    tile-1-pos :: <pos>, tile-1 :: <movable>,
    tile-2-pos :: <pos-or-false>, tile-2 :: <blocking-or-empty> );

// Movable tile pushed onto an empty tile; start slide
// which will terminate after traversing one or more
// tiles.
define method collide( model :: <model>, dir :: <dir>,
    movable-pos :: <pos>, movable-tile :: <movable>,
    next-pos :: <pos>, next-tile :: <empty> )
    format-out( "collide: movable / empty\n" );
//    force-out();
    slide ( model, dir, movable-pos, movable-tile,
            next-pos, next-tile );
end;

// When an ice block is pushed directly against any other
// blocking tile, it is destroyed.
define method collide( model :: <model>, dir :: <dir>,
    ice-block-pos :: <pos>, ice-block-tile :: <ice-block>,
    icebreaking-pos :: <pos-or-false>,
    ice-breaking-tile :: <blocking> )
    format-out( "collide: ice-block / blocking\n" );
    force-out();
    setTileAtPos( model, ice-block-pos, $the-empty );
end;

// When a heart meets a house, it is removed from play.
// The board is completed when all the hearts are sent
// into houses.
define method collide( model :: <model>, dir :: <dir>,
    heart-pos :: <pos>, heart-tile :: <heart>,
    house-pos :: <pos>, house-tile :: <house> )
    format-out( "collide: heart / house\n" );
//    force-out();
    setTileAtPos( model, heart-pos, $the-empty );
    decrementHeartCount( model );
end;

// When a bomb meets a mountain, both bomb and mountain
// are removed from play.
define method collide( model :: <model>, dir :: <dir>,
    bomb-pos :: <pos>, bomb-tile :: <bomb>,
    mountain-pos :: <pos>, mountain-tile :: <mountain> )
    format-out( "collide: bomb / mountain\n" );
    force-out();
    setTileAtPos( model, bomb-pos, $the-empty );
    setTileAtPos( model, mountain-pos, $the-empty );
end;

// When a generic movable piece meets any other
// blocking pieces other than in the special cases
// above, it just stops. Maybe play a "fail" beep.
define method collide( model :: <model>, dir :: <dir>,
    movable-pos :: <pos>, movable-tile :: <movable>,
    blocking-pos :: <pos-or-false>, blocking-tile :: <blocking> )
    format-out( "collide: movable / blocking \n" );
    force-out();
end;

// pushTile represents the penguin (player avatar)
// pushing a tile. We specialize on 3 abstract
// subclasses of <tile> which together cover all
// the subclasses, so there should be no possible
// un-handled classes.
define generic pushTile( model :: <model>, dir :: <dir>,
    pos :: <pos-or-false>, target-tile :: <tile> );

// Handle walkable (empty or tree tile). The penguin
// is allowed to move onto this tile (indicated by
// returning #t).
define method pushTile( model :: <model>, dir :: <dir>,
    target-pos :: <pos>, target-tile :: <walkable> )
    => ( result :: <boolean> )
    format-out( "pushTile: walkable\n" );
    force-out();
    model.penguin-pos := target-pos;
    #t;
end;

// Handle movable (bomb, heart, ice block) -- call
// collide which specializes in various combinations.
define method pushTile( model :: <model>, dir :: <dir>,
    target-pos :: <pos>, target-tile :: <movable> )
    => ( result :: <boolean> )
    format-out( "pushTile: movable\n" );
    force-out();
    let next-pos :: <pos-or-false>  =
        getAdjacentPos( target-pos, dir );
    let next-tile = getTileAtPos ( model, next-pos );
    collide( model, dir, target-pos, target-tile,
        next-pos, next-tile );
    #f;
end;

// Handle fixed (house, mountain, edge) -- do nothing.
// The GUI might play a "fail" beep.
define method pushTile( model :: <model>, dir :: <dir>,
    target-pos :: <pos-or-false>, target-tile :: <fixed> )
    => ( result :: <boolean> )
    format-out( "pushTile: fixed\n" );
    force-out();
    #f;
end;

define method getTileAtXY( model :: <model>,
    y-idx :: <integer>, x-idx :: <integer> ) =>
    ( tile :: <tile> )
    model.board[ y-idx, x-idx ];
end;

define method getTileAtPos( model :: <model>, pos :: <pos-or-false> ) =>
    ( tile :: <tile> )
    if ( pos )
        getTileAtXY( model, pos.y-idx, pos.x-idx );
    else
        $the-edge;
    end if;
end;

define function getAdjacentPos( pos :: <pos>, dir :: <dir> )
    => ( pos-or-false :: <pos-or-false> )
    let y-offset :: <integer> = 0;
    let x-offset :: <integer> = 0;
    if ( dir == #"east" )
        x-offset := 1;
    elseif ( dir == #"south" )
        y-offset := 1;
    elseif ( dir == #"west" )
        x-offset := -1;
    elseif ( dir == #"north" )
        y-offset := -1;
    end if;
    let new-y-idx :: <integer> = pos.y-idx + y-offset;
    let new-x-idx :: <integer> = pos.x-idx + x-offset;
    if ( ( ( new-y-idx >= 0 ) & ( new-y-idx < $board-dim-y ) ) &
         ( ( new-x-idx >= 0 ) & ( new-x-idx < $board-dim-x ) ) )
        make( <pos>, y-idx: new-y-idx, x-idx: new-x-idx );
    else
        #f
    end if;
end;

define method setTileAtXY( model :: <model>,
    y-idx :: <integer>, x-idx :: <integer>, tile :: <tile> )
    model.board[ y-idx, x-idx ] := tile;
end;

define method setTileAtPos( model :: <model>, pos, tile :: <tile> )
    format-out( "setTileAtPos: [ %d, %d ]: %S\n",
        pos.y-idx, pos.x-idx, tile );
    force-out();
    setTileAtXY( model, pos.y-idx, pos.x-idx, tile );
end;

define function getPolarTileAtXY( y-idx :: <integer>, x-idx :: <integer> )
    => ( char :: <character> )
    $polar-level-1[ y-idx * $board-dim-x + x-idx ];
end;

define method penguinPush( model :: <model> )
    => ( result :: <boolean> )
    let target-pos :: <pos-or-false> =
        getAdjacentPos( model.penguin-pos, model.penguin-dir );
    let target-tile = getTileAtPos( model, target-pos );
    pushTile( model, model.penguin-dir, target-pos, target-tile );
end;

define method penguinMove( model :: <model>, dir :: <dir> )
    if ( model.penguin-dir ~= dir )
        model.penguin-dir := dir;
        format-out( "Penguin changed dir to %S\n", dir );
        force-out();
    else
        if ( penguinPush( model ) )
            format-out ( "Penguin moved to %d, %d\n",
                model.penguin-pos.y-idx, model.penguin-pos.x-idx );
            force-out();
        end if;
        if ( model.heart-count == 0 )
            format-out( "Heart count reached zero, level cleared!\n" );
            force-out();
        end if;
    end if;
end;

define method penguinMoveTimes( model :: <model>, dir :: <dir>, times :: <integer> )
    for ( count from 1 to times )
        penguinMove( model, dir );
    end for;
end;

define method decrementHeartCount( model :: <model> )
    model.heart-count := model.heart-count - 1;
end;

define method init( model :: <model> )
    model.penguin-pos := make( <pos>, y-idx: 0, x-idx: 0 );
    model.penguin-dir := #"south";
    model.heart-count := 3;
    model.board := make( <array>, dimensions: list( $board-dim-y, $board-dim-x ) );
    for ( y-idx from 0 below $board-dim-y )
        for ( x-idx from 0 below $board-dim-x )
            let tile-val :: <character> =
                getPolarTileAtXY( y-idx, x-idx );
            model.board[ y-idx, x-idx ] :=
                case
                    ( tile-val == '0' ) => $the-empty;
                    ( tile-val == '1' ) => $the-tree;
                    ( tile-val == '2' ) => $the-mountain;
                    ( tile-val == '3' ) => $the-house;
                    ( tile-val == '4' ) => $the-ice-block;
                    ( tile-val == '5' ) => $the-heart;
                    ( tile-val == '6' ) => $the-bomb;
                    otherwise => format-out( "Bad tile value!\n"); $the-empty;
                end case;
        end for;
    end for;
end;

define method describe-tile( tile :: <tile> ) => ( str :: <string> )
    case
        ( tile == $the-empty     ) => "___ ";
        ( tile == $the-tree      ) => "tre ";
        ( tile == $the-mountain  ) => "mtn ";
        ( tile == $the-house     ) => "hou ";
        ( tile == $the-ice-block ) => "ice ";
        ( tile == $the-heart     ) => "hea ";
        ( tile == $the-bomb      ) => "bom ";
        otherwise                  => "??? ";
    end case;
end method;

define method describe-board( model :: <model> )
    for ( y-idx from 0 below $board-dim-y )
        for ( x-idx from 0 below $board-dim-x )
            format-out( "%S",
                describe-tile( model.board[ y-idx, x-idx ]  ) );
        end for;
        format-out( "\n" );
    end for;
    force-out();
end;

define function main
    (name :: <string>, arguments :: <vector>)
    format-out("Testing the arctic-slide game mechanics with test board 1\n");

    let model :: <model> = make( <model>, y-idx: 0, x-idx: 0 );
    init( model );

    describe-board( model );

    penguinMoveTimes( model, #"east", 21 );
    penguinMoveTimes( model, #"south", 2 );
    penguinMoveTimes( model, #"east", 3 );
    penguinMoveTimes( model, #"north", 2 );
    penguinMoveTimes( model, #"west", 2 );

    describe-board( model );

    penguinMoveTimes( model, #"south", 4 );
    penguinMoveTimes( model, #"west", 7 );
    penguinMoveTimes( model, #"north", 2 );

    describe-board( model );

    penguinMoveTimes( model, #"west", 14 );
    penguinMoveTimes( model, #"north", 3 );
    penguinMoveTimes( model, #"west", 2 );
    penguinMoveTimes( model, #"north", 2 );
    penguinMoveTimes( model, #"west", 3 );
    penguinMoveTimes( model, #"south", 2 );
    penguinMoveTimes( model, #"west", 2 );
    penguinMoveTimes( model, #"south", 3 );
    penguinMoveTimes( model, #"east", 2 );

    describe-board( model );

    penguinMoveTimes( model, #"east", 5 );
    penguinMoveTimes( model, #"north", 3 );
    penguinMoveTimes( model, #"east", 3 );
    penguinMoveTimes( model, #"south", 2 );

    describe-board( model );

    penguinMoveTimes( model, #"east", 3 );
    penguinMoveTimes( model, #"south", 2 );
    penguinMoveTimes( model, #"west", 2 );
    penguinMoveTimes( model, #"north", 2 );
    penguinMoveTimes( model, #"west", 3 );
    penguinMoveTimes( model, #"south", 2 );
    penguinMoveTimes( model, #"west", 3 );
    penguinMoveTimes( model, #"south", 3 );
    penguinMoveTimes( model, #"east", 3 );

    describe-board( model );

    penguinMoveTimes( model, #"east", 11 );
    penguinMoveTimes( model, #"north", 2 );
    penguinMoveTimes( model, #"west", 11 );
    penguinMoveTimes( model, #"north", 2 );
    penguinMoveTimes( model, #"west", 2 );
    penguinMoveTimes( model, #"south", 2 );
    penguinMoveTimes( model, #"west", 3 );
    penguinMoveTimes( model, #"south", 3 );
    penguinMoveTimes( model, #"east", 3 );

    describe-board( model );

    penguinMoveTimes( model, #"west", 2 );
    penguinMoveTimes( model, #"north", 3 );
    penguinMoveTimes( model, #"east", 2 );
    penguinMoveTimes( model, #"south", 2 );
    penguinMoveTimes( model, #"west", 2 );
    penguinMoveTimes( model, #"south", 3 );
    penguinMoveTimes( model, #"east", 2 );

    describe-board( model );

    exit-application(0);
end function;

// Calling our top-level function (which may have any name) is the last
// thing we do.
main(application-name(), application-arguments());
