
use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile
(

  NAME          => 'LinkedList::Single',
  VERSION       => '0.99.4',
  ABSTRACT_FROM => 'lib/LinkedList/Single.pm',
  PREREQ_PM     =>
  {
    # standard distro, particular versions 
    # are unlikely to cause pain.

    strict              => 0,
    overload            => 0,

    Carp                => 0,
    Symbol              => 0,
    Scalar::Util        => 0,
    Test::More          => 0,
    ExtUtils::MakeMaker => 0,
  },

);
