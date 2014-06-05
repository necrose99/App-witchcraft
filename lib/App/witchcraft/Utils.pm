package App::witchcraft::Utils;
use warnings;
use strict;
use base qw(Exporter);
use Term::ANSIColor;
use constant debug => $ENV{DEBUG};
use Git::Sub;
use Tie::File;
use Term::ReadKey;
use App::Nopaste 'nopaste';
use File::Basename;
use Fcntl qw(LOCK_EX LOCK_NB);
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;

our @EXPORT = qw(_debug
    info
    error
    notice
    send_report
    print_list
    test_untracked
    clean_untracked
    test_ebuild
    uniq
    password_dialog
    atom
    daemonize
    depgraph
    calculate_missing
);

sub calculate_missing($$) {
    my $package  = shift;
    my $depth    = shift;
    my @Packages = &depgraph( $package, $depth );    #depth=0 it's all
    &info( scalar(@Packages) . " dependencies found " );
    my @Installed_Packages = qx/equo q -q list installed/;
    chomp(@Installed_Packages);
    my %packs = map { $_ => 1 } @Installed_Packages;
    my @to_install = uniq( grep( !defined $packs{$_}, @Packages ) );
    shift @to_install;
    return @to_install;
}

sub depgraph($$) {
    my $package = shift;
    my $depth   = shift;
    return
        map { $_ =~ s/\[.*\]|\s//g; &atom($_); $_ }
        qx/equery -C -q g --depth=$depth $package/;    #depth=0 it's all
}

sub send_report {
    my $message = shift;
    my $ua      = LWP::UserAgent->new;
    &info( 'Sending ' . $message );
    my $hostname = $App::witchcraft::HOSTNAME;
    my @BULLET   = App::witchcraft::Config->param('ALERT_BULLET');
    my $success  = 0;
    if (@_) {
        my $log = join( "\n", @_ );
        &notice( 'Attachment ' . $log );
        my $url = nopaste(
            text    => $log,
            private => 1,      # default: 0

           # this is the default, but maybe you want to do something different
            error_handler => sub {
                my ( $error, $service ) = @_;
                warn "$service: $error";
            },

            warn_handler => sub {
                my ( $warning, $service ) = @_;
                warn "$service: $warning";
            },

            # you may specify the services to use - but you don't have to
            #     services => [ "pastie" ],
        );

        foreach my $BULL (@BULLET) {
            my $req = POST 'https://api.pushbullet.com/v2/pushes',
                [
                type  => 'link',
                title => "Witchcraft\@$hostname: " . $message,
                url   => $url
                ];
            $req->authorization_basic($BULL);
            my $res = $ua->request($req)->as_string;
            if ( $res =~ /HTTP\/1.1 200 OK/mg ) {
                &notice("Push sent correctly!");
                $success = 1;
            }
            else {
                &error("Error sending the push!");
                $success = 0;
            }
        }
    }
    else {
        &info('WOOOW BULLETS!');
        foreach my $BULL (@BULLET) {
            my $req = POST 'https://api.pushbullet.com/v2/pushes',
                [
                type  => 'note',
                title => 'Witchcraft@' . $hostname,
                body  => $message
                ];
            $req->authorization_basic($BULL);
            my $res = $ua->request($req)->as_string;
            if ( $res =~ /HTTP\/1.1 200 OK/mg ) {
                &notice("Push sent correctly!");
                $success = 1;
            }
            else {
                &error("Error sending the push!");
                $success = 0;
            }
        }

    }
    return $success;
}

sub daemonize($) {
    our ( $ProgramName, $PATH, $SUFFIX ) = fileparse($0);

    open( SELFLOCK, "<$0" ) or die("Couldn't open $0: $!\n");

    #  flock( SELFLOCK, LOCK_EX | LOCK_NB )
    #      or die("Aborting: another $ProgramName is already running\n");
    open( STDOUT, "|-", "logger -t $ProgramName" )
        or die("Couldn't open logger output stream: $!\n");
    open( STDERR, ">&STDOUT" )
        or die("Couldn't redirect STDERR to STDOUT: $!\n");
    $| = 1; # Make output line-buffered so it will be flushed to syslog faster
            # chdir('/')
      #    ; # Avoid the possibility of our working directory resulting in keeping an otherwise unused filesystem in use
    exit if ( fork() );
    exit if ( fork() );
    sleep 1 until getppid() == 1;
    print "$ProgramName $$ successfully daemonized\n";

}

sub atom { s/-[0-9]{1,}.*$//; }

sub _debug {
    print STDERR @_, "\n" if debug;
}

sub password_dialog {
    return undef if $> == 0;
    &info("Password: ");
    ReadMode('noecho');    # don't echo
    chomp( my $password = <STDIN> );
    ReadMode(0);           # back to normal
    &notice(
        "Note: ensure to give the right password, or install tests would fail"
    );
    $password = &password_dialog
        unless (
        system( 'echo ' . $password . ' | sudo -S echo Password OK' ) == 0 );
    return $password;
}

sub clean_untracked {
    my $dir = shift;
    my @Installed;
    chdir($dir);
    system("git ls-files --others --exclude-standard | xargs rm -rfv");
    &notice(
        "Launch 'git stash' if you want to rid about all the modifications");
}

sub uniq {
    return keys %{ { map { $_ => 1 } @_ } };
}

sub test_ebuild {
    my $ebuild   = shift;
    my $manifest = shift || undef;
    my $install  = shift || undef;
    my $password = shift || undef;
    if ( $> != 0 ) {
        $password = $password ? "echo $password | sudo -S " : "sudo";
    }
    else {
        $password = "";
    }
    system( $password. " ebuild $ebuild clean" )
        ;    #Cleaning before! at least it fails :P
    if ( defined $manifest and system("ebuild $ebuild manifest") == 0 ) {
        &notice('|| - Manifest created successfully');
        &error("|===================================================/")
            and return 1
            if ( defined $manifest and !defined $install );
        &notice("Starting installation");
        $ebuild =~ s/\.ebuild//;
        my @package=split(/\//,$ebuild);
        $ebuild=$package[0]."/".$package[2];
        $ebuild = "=" . $ebuild;
        &info(    "PORTDIR_OVERLAY='"
                . App::witchcraft::Config->param('GIT_REPOSITORY')
                . "' emerge -n "
                . $ebuild );
        if (defined $install
            and system( $password
                    . " PORTDIR_OVERLAY='"
                    . App::witchcraft::Config->param('GIT_REPOSITORY')
                    . "' emerge -n $ebuild"
            ) == 0
            )
        {
            &info('|| - Installation OK');
            return 1;
        }
        else { &error("Installation failed") and return 0; }
    }
    else { &error("Manifest failed") and return 0; }
}

sub test_untracked {
    my $dir      = shift;
    my $ignore   = shift || 0;
    my $password = shift || undef;
    my @Installed;
    chdir($dir);
    my @Failed;
    my @ignores;
    my @Untracked = git::ls_files '--others', '--exclude-standard';
    push( @Untracked, git::diff_files '--name-only' );
    @Untracked = grep {/\.ebuild$/} @Untracked;
    &info( "Those are the file that would be tested: "
            . join( " ", @Untracked ) );

    foreach my $new_pos (@Untracked) {
        &info("Testing $new_pos");
        my $result = &test_ebuild( $new_pos, 1, 1, $password );
        $new_pos =~ s/(.*\/[\w-]*)\/.*/$1/;
        if ( $result == 1 ) {

            #  &info( $new_pos . " was correctly installed" );
            push( @Installed, $new_pos );
        }
        else {
            # &error( $new_pos . " installation failed" );
            push( @Failed, $new_pos );
        }
    }
    if ( $ignore == 1 and @Failed > 0 ) {
        tie @ignores, 'Tie::File', ${App::witchcraft::IGNORE}
            or die( error $!);
        &send_report(
            "Witchcraft need your attention, i'm asking you few questions");
        foreach my $fail (@Failed) {
            push( @ignores, $fail )
                if (
                &dialog_yes_default(
                    "Add " . $fail . " to the ignore list?"
                )
                );
        }
    }
    if ( @Installed > 0 ) {
        &info(
            "Those files where correctly installed, maybe you wanna check them: "
        );
        my $result;
        &notice($_) and $result .= " " . $_ for ( &uniq(@Installed) );
        &send_report("Those ebuilds where correctly installed: $result");
        &info("Generating the command for maintenance");
        &notice("git add $result");
        &notice("eix-sync");
        &notice("emerge -av $result");
        &notice("eit add $result");
        &notice("eit push");
    }
    else {
        &info(
            "No files where tested because there weren't untracked files or all packages failed to install"
        );
    }
}

sub print_list {
    my @lines = @_;

    my $column_w = 0;

    map { $column_w = length( $_->[0] ) if length( $_->[0] ) > $column_w; }
        @lines;

    my $screen_width = 92;

    for my $arg (@lines) {
        my $title   = shift @$arg;
        my $padding = int($column_w) - length($title);

        if ( $ENV{WRAP}
            && ( $column_w + 3 + length( join( " ", @$arg ) ) )
            > $screen_width )
        {
            # wrap description
            my $string
                = color('bold')
                . $title
                . color('reset')
                . " " x $padding . " - "
                . join( " ", @$arg ) . "\n";

            $string =~ s/\n//g;

            my $cnt       = 0;
            my $firstline = 1;
            my $tab       = 4;
            my $wrapped   = 0;
            while ( $string =~ /(.)/g ) {
                $cnt++;

                my $c = $1;
                print $c;

                if ( $c =~ /[ \,]/ && $firstline && $cnt > $screen_width ) {
                    print "\n" . " " x ( $column_w + 3 + $tab );
                    $firstline = 0;
                    $cnt       = 0;
                    $wrapped   = 1;
                }
                elsif ($c =~ /[ \,]/
                    && !$firstline
                    && $cnt > ( $screen_width - $column_w ) )
                {
                    print "\n" . " " x ( $column_w + 3 + $tab );
                    $cnt     = 0;
                    $wrapped = 1;
                }
            }
            print "\n";
            print "\n" if $wrapped;
        }
        else {
            print color 'bold';
            print $title;
            print color 'reset';
            print " " x $padding;
            print " - ";
            $$arg[0] = ' ' unless $$arg[0];
            print join " ", @$arg;
            print "\n";
        }

    }
}

sub error {
    my @msg = @_;
    print STDERR color 'red';
    print STDERR '@@@ ' . join( "\n", @msg ), "\n";
    print STDERR color 'reset';
}

sub info {
    my @msg = @_;
    print STDERR color 'green';
    print STDERR '|| --> ' . join( "\n", @msg ), "\n";
    print STDERR color 'reset';
}

sub notice {
    my @msg = @_;
    print STDERR color 'bold yellow';
    print STDERR '/!\ ' . join( "\n", @msg ), "\n";
    print STDERR color 'reset';
}

sub dialog_yes_default {
    my $msg = shift;
    local $|;
    print STDERR color 'bold blue';
    print STDERR '~~> ' . $msg;
    print STDERR ' (Y/n) ';
    print STDERR color 'reset';
    my $a = <STDIN>;
    chomp $a;

    if ( $a =~ /n/ ) {
        return 0;
    }
    return 1 if $a =~ /y/;
    return 1;    # default to Y
}

1;
