# Module to reduce boilerplate code in unburden-home-dir's test suite

# Boilerplate which exports into main::
use Test::More;
use Test::Differences;
use Test::File;
use File::Path qw(mkpath);
use File::Slurp;
use Data::Dumper;

package Test::UBH;

use Mouse;

# Boilerplate which exports into Test::UBH::
use Test::More;
use Test::Differences;
use Test::File;
use File::Path qw(mkpath rmtree);
use File::Slurp;
use File::Which;
use Data::Dumper;

foreach my $varname (qw(TESTNAME BASE HOME TARGET BASENAME PREFIX TP)) {
    has $varname => ( is => 'rw', isa => 'Str' );
}

sub new {
    my $class = shift;
    my $t = {};
    bless($t, $class);

    $t->TESTNAME(shift || 'generic-test');
    $t->BASE('t/'.$t->TESTNAME);
    $t->HOME($t->BASE . '/1');
    $t->TARGET($t->BASE .'/2');
    $t->BASENAME("unburden-home-dir_TEST_$$");
    $t->PREFIX('u');
    $t->TP($t->TARGET.'/'.$t->PREFIX);

    # Set a debug environment
    $ENV{HOME} = $t->HOME;
    $ENV{LANG} = 'C';

    # Clean up possible remainders of aborted tests
    rmtree($t->BASE);

    return $t;
}

sub cleanup {
    my $t = shift;
    ok( rmtree($t->BASE), "Clean up" );
}

sub done {
    my $t = shift;
    $t->cleanup;
    done_testing();
}

sub setup_test_environment {
    my $t = shift;
    $t->setup_test_environment_without_target(@_);
    $t->create_and_check_directory($t->TARGET,
                                   "test environment (target directory)" );
}

sub setup_test_environment_without_target {
    my $t = shift;
    foreach my $dir (@_) {
        $t->create_and_check_directory($t->HOME."/".($dir || ''),
                                       "test environment (home directory)" );
    }
}

sub create_and_check_directory {
    my $t = shift;
    my ($dir, $desc) = @_;
    ok( mkpath($dir, {}), "Create $desc" );
    ok( -d $dir, "$desc has been created" );
}

sub default_config {
    my $t = shift;
    return "TARGETDIR=".$t->TARGET."\nFILELAYOUT=".$t->PREFIX."-\%s";
}

sub prepend_lsof_warning {
    my $t = shift;
    my $wanted = shift || '';

    unless (which('lsof')) {
        $wanted = "WARNING: lsof not found, not checking for files in use.\n".$wanted;
    }

    return $wanted;
}

sub call_unburden_home_dir {
    my $t = shift;
    die 'Assertion: call_unburden_home_dir needs at least one non-empty parameter'
        unless @_;
    my $cmd =
        'bin/unburden-home-dir '.join(' ', @_).
        ' >'.$t->BASE.'/output 2>'.$t->BASE.'/stderr';
    ok( system($cmd) == 0, "Call '$cmd'" );
}

sub call_unburden_home_dir_user {
    my $t = shift;
    $t->call_unburden_home_dir(@_, '-b '.$t->BASENAME)
}

sub call_unburden_home_dir_default {
    my $t = shift;
    $t->call_unburden_home_dir(@_, "-C ".$t->BASE."/config -L ".$t->BASE."/list");
}

sub write_configs {
    my $t = shift;
    my ($list, $config) = @_;
    $t->write_config_file($t->BASE.'/list', $list || '',
                          "Write classic list" );
    $t->write_config_file($t->BASE.'/config', $config || $t->default_config,
                          "Write classic config" );
}

sub write_user_configs {
    my $t = shift;
    my ($list, $config) = @_;
    $t->write_config_file_to_home('.'.$t->BASENAME.'.list', $list || '',
                                  "Write classic list" );
    $t->write_config_file_to_home('.'.$t->BASENAME, $config || $t->default_config,
                                  "Write classic config" );
}

sub write_xdg_configs {
    my $t = shift;
    my ($list, $config) = @_;
    ok( mkpath($t->HOME.'/.config/'.$t->BASENAME, {}), "Create test environment (XDG directory)" );
    $t->write_config_file_to_home('.config/'.$t->BASENAME.'/list', $list || '',
                                  "Write XDG list" );
    $t->write_config_file_to_home('.config/'.$t->BASENAME.'/config', $config || $t->default_config,
                                  "Write XDG config" );
}

sub write_config_file_to_home {
    my $t = shift;
    my $file = shift;
    $t->write_config_file($t->HOME.'/'.$file, @_);
}

sub write_config_file {
    my $t = shift;
    my ($file, $contents, $desc) = @_;
    BAIL_OUT('write_config_file: $file empty') unless $file;
    BAIL_OUT('write_config_file: $contents undefined') unless defined $contents;

    ok( write_file($file, $contents),
        $desc || "Write config file $file" );
}

1;
