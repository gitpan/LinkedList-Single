
use v5.12;
use ExtUtils::MakeMaker;

WriteMakefile
(
    NAME            => 'LinkedList::Single',
    VERSION         => 'v0.99.21',
    ABSTRACT_FROM   => 'lib/LinkedList/Single.pm',
    LICENSE         => 'perl',
    PREREQ_PM       =>
    {
        qw
        (
            strict              0
            overload            0

            Carp                0
            Symbol              0
            Scalar::Util        0
            Test::More          0
            ExtUtils::MakeMaker 0
        )
    },
);

__END__
