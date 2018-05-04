use strict;
use warnings;

use Path::Iterator::Rule ();
use Test::TempDir::Tiny qw( tempdir );

my $dir;

BEGIN {
    $dir = tempdir();
}

use local::lib;

# Install in local lib even if it's already installed elsewhere
use lazy ( '-L', $dir, '--reinstall' );

use Capture::Tiny qw( capture );
use Test::More;
use Test::RequiresInternet (
    'cpanmetadb.plackperl.org' => 80,
    'fastapi.metacpan.org'     => 443,
);

my ($cb) = grep { ref $_ eq 'CODE' } @INC;
my ( $stdout, $stderr, @result ) = capture { $cb->( undef, 'Test::Needs' ) };
like( $stderr, qr{installed}, 'module installed' );

my $rule = Path::Iterator::Rule->new->file->nonempty;
my $next = $rule->iter($dir);
my $found;
while ( defined( my $file = $next->() ) ) {
    if ( $file =~ m{Needs.pm\z} ) {
        $found = 1;
        last;
    }
}
ok( $found, 'file installed locally' ) || ( note $stderr && note $stdout );

done_testing();