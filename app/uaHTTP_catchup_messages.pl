### uaHTTP catchup messages functions ###

### Functions ###

sub catchup_messages {

local $handle = shift;
my ($content, $uaresponse, $username) = @_;
my ($response, $request);

my %form = %{$content};

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

defined($form{folder}) || die "No folder passed to catchup_messages\n";

$request = clean EDF::Object("request", \"message_mark_read");
$request->addChild("folderid", $form{folder});

if (defined($form{message})) {
  $request->addChild("marktype", 1);
  $request->addChild("markkeep", 1);
  $request->addChild("crossfolder", 1);
  $request->addChild("messageid", get_ancestor(@form{"message", "folder"}));
  delete $content->{message};
} else {
  $request->addChild("marktype", 2);
}

$content->{messages} = "unread";

$response = $handle->request($request);
$request->DESTROY;

die "Message #$form{message} does not exist\n" if ($response->value eq "message_not_exist"); 
die "Folder #$form{folder} does not exist\n" if ($response->value eq "folder_not_exist"); 
die "Access to folder #$form{folder} invalid\n" if ($response->value eq "folder_access_invalid"); 

return 1;

}

###

sub get_ancestor {

local $::messageid = shift;
my $folderid = shift;
my ($response, $request);

$request = clean EDF::Object("request", \"message_list");
$request->addChild("searchtype", 1);
$request->addChild("folderid", $folderid);
$response = $handle->request($request);
$request->DESTROY;

return $::messageid unless ($response->value eq "message_list"); # This shouldn't happen!

my $ancestor;

if ($response->child("message")) {
  $ancestor = find_messageR($response);
}

$response->DESTROY;

return $ancestor || $::messageid;

}

###

sub find_messageR {

my $edf = shift;
my $found;
my $value;
my $ancestor;

do {{
  if ($found = ($edf->value == $::messageid)) { print "LAST\n"; last; }
  if ($edf->child("message")) {
    return $value if ($value = find_messageR($edf));
    $edf->parent;
  }
}} while ( (! $found) && $edf->next("message") );

return unless $found;

while ($edf->parent) {
  last unless ($edf->name eq "message");
  $ancestor = $edf->value;
}

return $ancestor;

}

###
1;
