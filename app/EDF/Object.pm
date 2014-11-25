package EDF::Object;

use EDF::Constants qw#:location#;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(pretty display);
$VERSION = 0.5;

use strict;

###

sub add {

my $object   = shift;
my $name     = shift;
my $value    = shift;
my $position = shift;

$position = EDF_ABSLAST unless (defined $position);

$object->_add($name, $value, $position, 1);

return $object;

}

###

sub addChild {

my $object   = shift;
my $name     = shift;
my $value    = shift;
my $position = shift;

$position = EDF_ABSLAST unless (defined $position);

$object->_add($name, $value, $position, 0);

return $object;

}

###

sub _add {

my $root   = shift;
my $object = $root->{POINTER};
my $class  = ref($object) || die "Not an object";

my $self = {
  NAME     => shift,
  VALUE    => shift,
  CHILDREN => [ ],
  PARENT   => undef,
};

bless($self, $class);

my $position = shift;

$self->{PARENT} = $object;
$object->_addElement($position, $self);

$root->{POINTER} = $self if shift;

}

###

sub _addElement {

my $object     = shift;
my $position   = shift;
my $newelement = shift;

if ($newelement) {

  my $offset;
  my $ref = $object->{CHILDREN};

  if ($position == EDF_FIRST) {

    for ($offset = 0; $offset < @$ref; $offset++) {
      last if ($ref->[$offset]->{NAME} eq $newelement->{NAME});
    }
    $offset = 0 if ($offset > @$ref);

  } elsif ($position == EDF_LAST)     {

    for ($offset = @$ref - 1; $offset >= 0; $offset--) {
      last if ($ref->[$offset]->{NAME} eq $newelement->{NAME});
    }
    $offset++;
    $offset = @$ref if ($offset == 0);

  } elsif ($position == EDF_ABSFIRST) {
    $offset = 0;
  } elsif ($position == EDF_ABSLAST)  {
    $offset = @$ref;
  } elsif ($position < 1)  {
    $offset = @$ref;
  } else { # numeric offset
  
    for ($offset = 0; ($offset < @$ref) && ($position); $offset++) {
      $position-- if ($ref->[$offset]->{NAME} eq $newelement->{NAME});
    }

  }

  splice(@$ref, $offset, 0, $newelement);

}

}

###

sub clean {

my $object = shift;

my $class = ref($object) || $object;

my $self = {
  NAME      => shift,
  VALUE     => shift,
  CHILDREN  => [ ],
  PARENT    => undef,
  POINTER   => undef,
  STACK     => [ ],
};

bless($self, $class);

$self->{PARENT}  = $self;
$self->{POINTER} = $self;

return $self;

}

###

sub name {

my $root = shift;
if (@_) { $root->{POINTER}->{NAME} = shift }
return $root->{POINTER}->{NAME};

}

###

sub value {

my $root = shift;
if (@_) { $root->{POINTER}->{VALUE} = shift }
return (ref $root->{POINTER}->{VALUE})?${$root->{POINTER}->{VALUE}}:$root->{POINTER}->{VALUE};

}

###

sub each {

my $root = shift;
if (@_) { ($root->{POINTER}->{NAME}, $root->{POINTER}->{VALUE}) = @_ }
return ($root->{POINTER}->{NAME}, (ref $root->{POINTER}->{VALUE})?${$root->{POINTER}->{VALUE}}:$root->{POINTER}->{VALUE});

}

###

sub parent {

my $root = shift;
$root->{POINTER} = $root->{POINTER}->{PARENT};
return $root;

}

###

sub children {

my $root = shift;
if (@_) { @{ $root->{POINTER}->{CHILDREN} } = @_ }
return $root->{POINTER}->{CHILDREN};

}

###

sub DESTROY {

my $self = shift;

#print join(" ~ ", "DESTROY", $self, $self->{NAME}, (ref $self->{VALUE})?${$self->{VALUE}}:$self->{VALUE}, "\n");

if (defined($self->{CHILDREN}) && scalar(@{$self->{CHILDREN}})) {

  foreach (grep {defined} @{$self->{CHILDREN}}) {
    $_->DESTROY;
  }

}

$self->{NAME}     = undef;
$self->{VALUE}    = undef;
$self->{CHILDREN} = undef;

{ local $^W = 0;

  if ($self->{PARENT} eq $self) {
    $self->{PARENT}   = undef;
    $self->{POINTER}  = undef;
    $self->{STACK}    = undef;
  }

}

undef $self;

}

###

sub root {

my $root = shift;
return $root->{POINTER} = $root;

}

###

sub toEDF {

my $object = shift;

local $::edf;

$object->_toEDFRecursive;

return $::edf;

}

###

sub _toEDFRecursive {

my $object = shift;
my ($name, $value) = ($object->{NAME}, $object->{VALUE});

if (ref $value) {
  $value = $$value;
  $value =~ s#\\#\\\\#g;
  $value =~ s#"#\\"#g;
  $value = qq#"$value"#;
}

$name .= "=$value" if (defined $value);

if (scalar @{$object->{CHILDREN}}) {

  $::edf .= qq(<$name>);

  foreach (@{$object->{CHILDREN}}) {
    $_->_toEDFRecursive;
  }

  $::edf .= qq(</>);

} else {

  $::edf .= qq(<$name/>);

}

}

###

sub parseEDF {

my $object        = shift;
my $handle        = shift;

my $byte;
my $offset;

my $quote         = 0;
my $tag           = 0;
my $assign        = 0;
my $selfclosing   = 0;
my $closed        = 0;
my $string        = 0;

my $name          = "";
my $value         = "";

my $edf;
my @depth = ();

# open(DEBUG, ">> debugObject.log");
# select((select(DEBUG), $| = 1)[0]);

do {{

  $byte = $handle->readByte;
  return undef unless defined($byte);
  
# print DEBUG $byte;

  if ( ($quote) && ($byte eq '\\') ) {

    $byte = $handle->readByte;
    return undef unless defined($byte);

# print DEBUG $byte;

    if ($assign) {
      $value .= $byte;
    } else {
      $name  .= $byte;
    }

    next;

  }

  if ($byte eq '"') {
    $quote = ! $quote;
    $string = 1;
    redo;
  }

  if ( ($byte ne '<') && (! $tag) ) {
    redo;
  }

  if ( ($byte eq '<') && (! $quote) && ($tag) ) {
    die "Tag start in middle of tag: $byte\n\n", $edf->toEDF, "\n\n", $handle->dumpStack;
  }

  if ( ($byte eq '<') && (! $quote) ) {
    $tag = 1;
    $value = "";
    $name = "";
    $selfclosing = 0;
    $assign = 0;
    $string = 0;
    redo;
  }

  if ( ($byte eq '/') && (! $quote) ) {

    if ($name eq "") {
      pop(@depth) || last;
      $edf->parent;
      $tag = 0;
      next;
    } else {
      $selfclosing = 1;
      redo;
    }

  }

  if ( ($byte eq '>') && (! $quote) ) {

    $tag = 0;
    $name = lc($name);

    $value = \"$value" if ($string);
    $value = undef unless ($assign);

    push(@depth, 1) unless ($selfclosing);

    unless ($edf) {
      $edf = $object->clean($name, $value);
      next;
    }

    if ($selfclosing == 0) {
      $edf->add($name, $value);
    } else {
      $edf->addChild($name, $value);
    }

    next;
  }

  if ( ($byte eq '=') && (! $quote) ) {
    $assign = 1;
    redo;
  }

  if ($assign) {
    $value .= $byte;
  } else {
    $name  .= $byte;
  }

  redo;

}} while (@depth);

# close(DEBUG);

return $edf || $object->clean;

}

###

sub delete {

my $root = shift;
my $object = $root->{POINTER};

# Prevent deletion of root element
return 0 if ($root eq $object);

my $child;

$root->parent;

for ($child = 0; $child < scalar @{$root->{POINTER}->{CHILDREN}}; $child++) {
  if ($root->{POINTER}->{CHILDREN}->[$child] eq $object) {
    splice(@{$root->{POINTER}->{CHILDREN}}, $child, 1);
    last;
  }
}

return $root;

}

###

sub elements {

my $root = shift;
my $object = $root->{POINTER};

my $child;
my %hash;

foreach $child (@{$object->{CHILDREN}}) {
  push(@{$hash{$child->{NAME}}}, (ref $child->{VALUE})?${$child->{VALUE}}:$child->{VALUE});
}

return %hash;

}

###

sub child {

my $root = shift;
my $name = shift;

return 0 unless (scalar @{$root->{POINTER}->{CHILDREN}});

unless (defined $name) {
  $root->{POINTER} = $root->{POINTER}->{CHILDREN}->[0];
  return $root;
}

my $rollback = $root->{POINTER};
$root->{POINTER} = $root->{POINTER}->{CHILDREN}->[0];

unless ($root->first($name)) {
  $root->{POINTER} = $rollback;
  return 0;
}

return $root;

}

###

sub next {

my $root = shift;
my $object = $root->{POINTER};
my $children = $root->{POINTER}->{PARENT}->{CHILDREN};
my $name = shift;

my $child;
my $found = 0;

for ($child = 0; $child < scalar(@$children); $child++) {

  if (! $found) {

    if ($children->[$child] eq $object) {
      if (defined $name) {
        $found = 1;
        next;
      } else {
        $root->{POINTER} = $children->[$child + 1];
        return $root;
      }
    }

  } else {

    if ($children->[$child]->{NAME} eq $name) {
      $root->{POINTER} = $children->[$child];
      return $root;
    }

  }
}

return 0;

}

###

sub prev {

my $root = shift;
my $object = $root->{POINTER};
my $children = $root->{POINTER}->{PARENT}->{CHILDREN};
my $name = shift;

my $child;
my $found = 0;

for ($child = scalar(@$children) - 1; $child >= 0; $child--) {

  if (! $found) {

    if ($children->[$child] eq $object) {
      if (defined $name) {
        $found = 1;
        next;
      } else {
        $root->{POINTER} = $children->[$child - 1];
        return $root;
      }
    }

  } else {

    if ($children->[$child]->{NAME} eq $name) {
      $root->{POINTER} = $children->[$child];
      return $root;
    }

  }
}

return 0;

}

###

sub first {

my $root = shift;
my $name = shift;
my $children = $root->{POINTER}->{PARENT}->{CHILDREN};

my $child;

unless (defined $name) {
  $root->{POINTER} = $children->[0];
  return $root;
}

for ($child = 0; $child < scalar(@$children); $child++) {
  if ($children->[$child]->{NAME} eq $name) {
    $root->{POINTER} = $children->[$child];
    return $root;
  }

}

return 0;

}

###

sub last {

my $root = shift;
my $name = shift;
my $children = $root->{POINTER}->{PARENT}->{CHILDREN};

my $child;

unless (defined $name) {
  $root->{POINTER} = $children->[-1];
  return $root;
}

for ($child = scalar(@$children) - 1; $child >= 0; $child--) {
  if ($children->[$child]->{NAME} eq $name) {
    $root->{POINTER} = $children->[$child];
    return $root;
  }

}

return 0;

}

###

sub push {

my $root = shift;
push (@{$root->{STACK}}, $root->{POINTER});

}

###

sub pop {

my $root = shift;
$root->{POINTER} = pop (@{$root->{STACK}});

}

###

sub pretty { my $string = shift; $string =~ s#([^\\]>)#$1\n#g; return $string; }
sub display { print join(":", @_), "\n"; }

###
1;
