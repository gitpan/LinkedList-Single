
use v5.12;
use autodie;
use ExtUtils::MakeMaker;

my $dest	= 'lib/LinkedList/Single.pm';

-e $dest && unlink $dest;

if( eval{ require v5.16 } )
{
	# beyond where the recursive destroy causes problems.

	link 'lib/LinkedList/Single-Post516.pm' => $dest;
}
else
{
	link 'lib/LinkedList/Single-Pre516.pm' => $dest;
}

WriteMakefile
(
    NAME            => 'LinkedList::Single',
    VERSION         =>  1.01,
    ABSTRACT_FROM   => $dest,
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
            Test::Deep          0
            ExtUtils::MakeMaker 0
        )
    },
);

__END__
