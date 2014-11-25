package EDF::Constants;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(Access Sex Login Folder ANSI);
%EXPORT_TAGS = (
	location => [EDF_FIRST, EDF_LAST, EDF_PREV, EDF_NEXT, EDF_ABSFIRST, EDF_ABSLAST],
);

Exporter::export_ok_tags('location');

use constant EDF_FIRST    =>  0;
use constant EDF_LAST     => -1;
use constant EDF_PREV     => -2;
use constant EDF_NEXT     => -3;
use constant EDF_ABSFIRST => -4;
use constant EDF_ABSLAST  => -5;

my %Access = (
	LEVEL_NONE	=> 0,
	LEVEL_GUEST	=> 1,
	LEVEL_MESSAGES	=> 2,
	LEVEL_EDITOR	=> 3,
	LEVEL_WITNESS	=> 4,
	LEVEL_SYSOP	=> 5,
);

my %Sex = (
	GENDER_PERSON	=> 0,
	GENDER_MALE	=> 1,
	GENDER_FEMALE	=> 2,
	GENDER_NONE	=> 3,
);

my %Login = (
	LOGIN_OFF	=> 0,
	LOGIN_ON	=> 1,
	LOGIN_BUSY	=> 2,
	LOGIN_IDLE	=> 4,
	LOGIN_TALKING	=> 8,
	LOGIN_AGENT	=> 16, # Deprecated in v2.2a
	LOGIN_GONE	=> 32, # Deprecated in v2.0
	LOGIN_SILENT	=> 64,
	LOGIN_NOCONTACT => 128, # Added in v2.5-alpha
	LOGIN_SHADOW	=> 256,
);

my %Folder = (
	FOLDER_SUB_READ		=>	1,
	FOLDER_SUB_WRITE	=>	2,
	FOLDER_SUB_SDEL		=>	4,
	FOLDER_SUB_ADEL		=>	8,
	FOLDER_MEM_READ		=>	16,
	FOLDER_MEM_WRITE	=>	32,
	FOLDER_MEM_SDEL		=>	64,
	FOLDER_MEM_ADEL		=>	128,
	FOLDER_PRIVATE		=>	256,
);

my %ANSI = (
	NORMAL		=> "[0m",
	WHITE		=> "[0;1m",
	RED		=> "[1;31m",
	GREEN		=> "[1;32m",
	YELLOW		=> "[1;33m",
	BLUE		=> "[1;34m",
	MAGENTA		=> "[1;35m",
	CYAN		=> "[1;36m",
);

my $key;

foreach $key (keys %Access) {
  $Access{$Access{$key}} = $key;
}

foreach $key (keys %Sex) {
  $Sex{$Sex{$key}} = $key;
}

foreach $key (keys %Login) {
  $Login{$Login{$key}} = $key;
}

foreach $key (keys %Folder) {
  $Folder{$Folder{$key}} = $key;
}

sub Access {
  return (defined $Access{$_[0]})?$Access{$_[0]}:undef;
}

sub Sex {
  return (defined $Sex{$_[0]})?$Sex{$_[0]}:undef;
}

sub Login {
  return (defined $Login{$_[0]})?$Login{$_[0]}:undef;
}

sub Folder {
  return (defined $Folder{$_[0]})?$Folder{$_[0]}:undef;
}

sub ANSI {
  return (defined $ANSI{$_[0]})?$ANSI{$_[0]}:"";
}

###
1;
