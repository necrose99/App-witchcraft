package App::witchcraft::Command::Align;

use base qw(App::witchcraft::Command);
use Carp::Always;
use App::witchcraft::Utils
    qw(error info notice send_report process last_commit atom compiled_commit);
use warnings;
use strict;
use Git::Sub qw(diff);

=encoding utf-8

=head1 NAME

App::witchcraft::Command::Align - Automatic compile from a commit

=head1 SYNOPSIS

  $ witchcraft align [commit]
  $ witchcraft a

=head1 DESCRIPTION

Automatic compile from a commit or the last automatic compiled

=head1 ARGUMENTS

=over 4

=item C<--help>

it prints the POD help.

=back

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<App::witchcraft>, L<App::witchcraft::Command::Euscan>

=cut

sub run {
    error 'You must run it with root permissions' and exit 1 if $> != 0;
    my $self = shift;
    my $last_commit = shift // compiled_commit();
    error 'No compiled commit could be found, you must specify it' and exit 1
        if ( !defined $last_commit );
    my $cfg = App::witchcraft->Config;
    chdir( $cfg->param('GIT_REPOSITORY') );
    my @FILES = map {
        $_ =~ s/.*\K\/.*?$//g;         #Removing the last part
        atom($_);                      #converting to atom
        $_ =~ s/.*\K\/Manifest$//g;    #removing manifest
        $_
        } grep {
        /Manifest$/i                   #Only with the manifest are interesting
        } git::diff( $last_commit, '--name-only' );
    notice 'Those are the packages that would be processed:';
    info "\t" . $_ for @FILES;
    my @EMERGING = map { $_ . "::" . $cfg->param('OVERLAY_NAME') } @FILES;
    process(
        @EMERGING,
        last_commit(
            $cfg->param('OVERLAY_PATH'),
            $cfg->param('GIT_MASTER_FILE')
        ),
        0
    );
}

1;
