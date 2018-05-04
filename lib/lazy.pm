package lazy;

use strict;
use warnings;

our $VERSION = '0.000002';

use App::cpm 0.974;    # CLI has no $VERSION
use App::cpm::CLI;

# Push the hook onto @INC and then re-add all of @INC again.  This way, if we
# got to the hook and tried to install, we can re-try @INC to see if the module
# can now be used.

sub import {
    shift;
    my @args = @_;

    push @INC, sub {
        shift;

        # Don't try to install if we're called inside an eval
        my @caller = caller(1);
        return
            if ( ( $caller[3] && $caller[3] =~ m{eval} )
            || ( $caller[1] && $caller[1] =~ m{eval} ) );

        my $name = shift;
        $name =~ s{/}{::}g;
        $name =~ s{\.pm\z}{};

        my $cpm = App::cpm::CLI->new;
        $cpm->parse_options(@args);

        # Generally assume a global install.  However, if we're already using
        # local::lib, let's try to DTRT and use the correct local::lib.  This
        # may or may not be a good idea.  Poking around in App::cpm's internals
        # is already a bad idea...

        if (
            exists $INC{'local/lib.pm'}
            && (
                !@args
                || (
                    (
                        !grep { $_ eq '-L' || $_ eq '--local-lib-contained' }
                        @args
                    )
                    && !$cpm->{global}
                )
            )
        ) {
            my @paths = local::lib->new->active_paths;
            my $path  = shift @paths;
            if ($path) {
                push @args, ( '-L', $path );
                _print_msg_about_local_lib($path);
            }
        }

        $cpm->parse_options(@args);

        # Assume a global install if no args are supplied and local::lib is not
        # in use.  Originally I went with the defaults of installing to
        # "local", but I constantly had to look remind myself how to do this,
        # especially since I'd need to use local::lib to get the code to run as
        # well.  The truly lazy way to do this is to default to the global
        # install and let folks who need to sandbox their module installs take
        # the extra steps.

        @args = ('-g') unless @args;

        $cpm->run( 'install', @args, $name );
        return 1;
    }, @INC;
}

sub _print_msg_about_local_lib {
    my $path = shift;

    print <<"EOF";

********

You haven't included any arguments for App::cpm via lazy, but you've
loaded local::lib, so we're going to install all modules into:

$path

If you do not want to do this, you can explicitly invoke a global install via:

    perl -Mlazy=-g path/to/script.pl

or, from inside your code:

    use lazy qw( -g );

********

EOF
}

1;

# ABSTRACT: Lazily install missing Perl modules

=pod

=head1 SYNOPSIS

    # Auto-install missing modules globally
    perl -Mlazy foo.pl

    # Auto-install missing modules into local_foo/.  Note local::lib needs to
    # precede lazy in this scenario in order for the script to compile on the
    # first run.
    perl -Mlocal::lib=local_foo -Mlazy foo.pl

    # Auto-install missing modules into local/
    use local::lib 'local';
    use lazy;

    # Auto-install missing modules globally
    use lazy;

    # Same as above, but explicity auto-install missing modules globally
    use lazy qw( -g );

    # Use a local::lib and get verbose, uncolored output
    perl -Mlocal::lib=foo -Mlazy=-v,--no-color

=head2 DESCRIPTION

Your co-worker sends you a one-off script to use.  You fire it up and realize
you haven't got all of the dependencies installed in your work environment.
Now you fire up the script and one by one, you find the missing modules and
install them manually.

Not anymore!

C<lazy> will try to install any missing modules automatically, making your day
just a little less long.  C<lazy> uses L<App::cpm> to perform this magic in the
background.

=head2 USAGE

You can pass arguments directly to L<App::cpm> via the import statement.

    use lazy qw( --verbose );

Or

    use lazy qw( --man-pages --with-recommends --verbose );

You get the idea.

This module uses L<App::cpm>'s defaults, with the exception being that we
default to global installs rather than local.

So, the default usage would be:

    use lazy;

If you want to use a local lib:

    use local::lib qw( my_local_lib );
    use lazy;

Lazy will automatically pick up on your chosen local::lib and install there.
Just make sure that you C<use local::lib> before you C<use lazy>.

=head2 CAVEATS

* If not installing globally, C<use local::lib> before you C<use lazy>

* Don't pass the C<-L> or C<--local-lib-contained> args directly to C<lazy>.  Use L<local::lib> directly to get the best (and least confusing) results.

* Remove C<lazy> before you put your work into production.

=head2 SEE ALSO

L<Acme::Magic::Pony>, L<lib::xi>, L<CPAN::AutoINC>, L<Module::AutoINC>

=head2 ACKNOWLEDGEMENTS

This entire idea was ripped off from L<Acme::Magic::Pony>.  The main difference
is that we use L<App::cpm> rather than L<CPAN::Shell>.

=cut

