use strict;
use warnings;

my $fixture = $ENV{FIXTURE};
open my $commands, '>>', "$fixture/commands" or die $!;
print {$commands} "stow @ARGV\n";
close $commands;
open my $state_file, '<', "$fixture/state" or die $!;
chomp(my $state = <$state_file>);
if ($state ne 'healthy') {
  if ($state eq 'unrelated') {
    print STDERR "permission denied loading another module\n";
  } else {
    print STDERR "Can't locate Stow.pm in \@INC\nBEGIN failed--compilation aborted\n";
  }
  exit 2;
}
if ($ARGV[0] eq '--version') {
  print "stow fixture\n";
} elsif ($ARGV[0] eq '--simulate') {
  if (-e "$fixture/simulate-error") {
    print STDERR "unexpected simulation error\n";
    exit 2;
  }
  if (-e "$fixture/conflict") {
    print "WARNING! stowing pkg would cause conflicts:\n";
    print "  * existing target is not owned by stow: .example\n";
    exit 1;
  }
  print "LINK: .example => pkg/.example\n";
} else {
  symlink "$fixture/pkg/.example", "$fixture/home/.example" or die $!;
}
