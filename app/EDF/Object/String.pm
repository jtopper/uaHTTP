package EDF::Object::String;

use EDF::Object;

sub parseString {

my $object = shift;
my $class  = ref($object) || $object;
my $string = shift;
my $self   = \$string;

bless($self, $class);

return EDF::Object::parseEDF("EDF::Object", $self);

}

sub readByte {

my $object = shift;

return substr($$object, 0, 1, '');

}

###
1;
