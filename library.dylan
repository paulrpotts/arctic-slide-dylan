module: dylan-user

define library arctic-slide
  use common-dylan;
  use io;
end library;

define module arctic-slide
  use common-dylan, exclude: { format-to-string };
  use format-out;
  use streams;     // for force-output( *standard-output* )
  use standard-io; // ditto
end module;
