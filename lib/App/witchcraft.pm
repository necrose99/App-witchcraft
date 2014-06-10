package App::witchcraft;
use strict;
use 5.008_005;
use App::CLI;
use Config::Simple;

our $VERSION              = 0.007;
our $CONFIG_FILE          = "witchcraft.conf";
our $IGNORE_FILE          = "ignored.packages";
our $WITCHCRAFT_DIRECTORY = ".witchcraft";
our $HOME                 = join( "/", $ENV{HOME}, $WITCHCRAFT_DIRECTORY );
our $CONFIG
    = -e join( "/", $HOME, $CONFIG_FILE )
    ? join( "/", $HOME, $CONFIG_FILE )
    : join( "/", '.',   $CONFIG_FILE );
our $IGNORE
    = -e join( "/", $HOME, $IGNORE_FILE )
    ? join( "/", $HOME, $IGNORE_FILE )
    : join( "/", '.',   $IGNORE_FILE );
our $CONFIG
    = ( -e $CONFIG )
    ? Config::Simple->new($CONFIG)
    : Config::Simple->new("./witchcraft.conf");
our $HOSTNAME = `hostname`;
chomp($HOSTNAME);

sub Config {
    return $CONFIG;
}

=encoding utf-8

=head1 NAME

App::witchcraft - Helps the overlay mantainer doing is dirty job

=head1 SYNOPSIS

  $ witchcraft --help
  $ --> Scan new packages and add to the git repository:
    *    e|--euscan  "v|verbose", Verbose mode
                                "q|quiet"  , Quiet mode
                                "c|check"  , Only check updates
                                "u|update" , Add it to the git repository
                                "r|root"   , Set root of the git repository
                                "m|manifest", Manifest each ebuild found
                                "i|install", Also Install it
                                "g|git"    , Stages git add and commit for each ebuild
                                "f|force", Force the -i and -m also if the ebuild is already present

    --> Checkout a repository and filter the ebuilds and add to the git repository (supports multiple repository)
    *    s|--sync       "u|update" , Add it to the git repository
                                "r|refactor=s", Modify the refactor term
                                "t|refactortarget=s", Modify the target of the refactoring
                                "r|root=s",  Set root of the git repository
                                "t|temp=s",  Temp directory for the svn checkout
                                "i|install", Try to install them, output the file that passed
                                "a|add", It asks to add the failed installed packages to ignore list
                                "-x|--ignore-existing", ignore existing files from rsync copy to the git overlay.
                                "-g|--git", add and push automatically to git and entropy repository
                                "-v|--verbose", be more verbose


    --> Install dependencies of a packages (if available) using equo
    *   d|depinstall   [package]
                                 "d|depth=i", define the deepness of the depdence tree, 0 to take all dependencies

    --> List repository packages
    *    l|list [repository]

    --> Emerge and push to entropy repository
    *    p|pack [package] [package2] ...

    --> Align to the last compiled commit (or the specified one)
    *    a|align [commit]

    --> Upgrades the packages and push to the entropy repository
    *    u|upgrade [repo]

    --> Watch for ebuild change in the configured overlay
    *    w|watch
                                "d|daemon", daemonize

    --> Manifest & install untracked files, giving a report of what packages succedeed
    *    t|test [repository dir]
                                 "a|add", It asks to add the failed installed packages to ignore list

    --> Clean all untracked files from the given repository
    *    c|clean [repository dir]


=head1 DESCRIPTION

App::witchcraft is an evil tool that do a lot of tasks: performs euscan for the atoms in a sabayon repository, test and update them, committing to the git repository...
Just invoke --help to see all the features

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>, skullbocks E<lt>skullbocks@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler, skullbocks

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO
L<App::witchcraft::Command::Euscan>, L<App::witchcraft::Command::Sync>

=cut

1;

