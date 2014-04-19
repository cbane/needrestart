# needrestart - Restart daemons after library updates.
#
# Authors:
#   Thomas Liske <thomas@fiasko-nw.net>
#
# Copyright Holder:
#   2013 - 2014 (C) Thomas Liske [http://fiasko-nw.net/~thomas/]
#
# License:
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this package; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
#

package NeedRestart;

use strict;
use warnings;
use Module::Find;
use NeedRestart::Utils;

use constant {
    NEEDRESTART_PRIO_LOW	=> 1,
    NEEDRESTART_PRIO_MEDIUM	=> 10,
    NEEDRESTART_PRIO_HIGH	=> 100,
};

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
    NEEDRESTART_PRIO_LOW
    NEEDRESTART_PRIO_MEDIUM
    NEEDRESTART_PRIO_HIGH

    needrestart_ui
    needrestart_interp_check
);

our @EXPORT_OK = qw(
    needrestart_ui_register
    needrestart_ui_init
    needrestart_interp_register
);

our %EXPORT_TAGS = (
    ui => [qw(
	NEEDRESTART_PRIO_LOW
	NEEDRESTART_PRIO_MEDIUM
	NEEDRESTART_PRIO_HIGH

	needrestart_ui_register
	needrestart_ui_init
    )],
    interp => [qw(
	needrestart_interp_register
    )],
);

our $VERSION = '0.6';

my %UIs;

sub needrestart_ui_register($$) {
    my $pkg = shift;
    my $prio = shift;

    $UIs{$pkg} = $prio;
}

sub needrestart_ui_init($$) {
    my $debug = shift;
    my $prefui = shift;

    # load prefered UI module
    if(defined($prefui)) {
	return if(eval "use $prefui; 1;");
    }

    # autoload UI modules
    foreach my $module (findsubmod NeedRestart::UI) {
	unless(eval "use $module; 1;") {
	    warn "Error loading $module: $@\n" if($@ && $debug);
	}
    }
}

sub needrestart_ui {
    my $debug = shift;
    my $prefui = shift;

    needrestart_ui_init($debug, $prefui) unless(%UIs);
    my ($ui) = sort { $UIs{$b} <=> $UIs{$a} } keys %UIs;

    return undef unless($ui);

    print STDERR "Using UI '$ui'...\n" if($debug);

    return $ui->new($debug);
}


my %Interps;

sub needrestart_interp_register($) {
    my $pkg = shift;

    $Interps{$pkg} = new $pkg();
}

sub needrestart_interp_init($) {
    my $debug = shift;

    # autoload Interp modules
    foreach my $module (findsubmod NeedRestart::Interp) {
	unless(eval "use $module; 1;") {
	    warn "Error loading $module: $@\n" if($@ && $debug);
	}
    }
}

sub needrestart_interp_check($$$) {
    my $debug = shift;
    my $pid = shift;
    my $bin = shift;

$debug++;

    needrestart_interp_init($debug) unless(%Interps);

    foreach my $interp (keys %Interps) {
	if($interp->isa($pid, $bin)) {
	    print STDERR "#$pid is a $interp\n" if($debug);

	    my $ps = nr_ptable_pid($pid);
	    my %files = $interp->files($pid);

	    if(grep {$_ > $ps->start} values %files) {
		if($debug) {
		    print STDERR "#$pid uses obsolete script file(s):";
		    print STDERR join("\n#$pid =>", '', map {($files{$_} > $ps->start ? $_ : ())} keys %files);
		    print STDERR "\n";
		}

		return 1;
	    }
	}
    }

    return 0;
}

1;
