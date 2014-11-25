### uaHTTP display search form and results functions ###

### Functions ###

sub display_search_form {

my ($handle, $content, $uaresponse, $username) = @_;
my ($html);

my %form = %$content;

if (exists $form{help}) {

  $html .= instructions();

} elsif ($form{form} eq "assisted") {
  $html .= display_assisted_search_form();

} else {

  $html = qq~
<html>
<head>
<title>Search</title>
<link rel=stylesheet type="text/css" href="ua.css">
</head>
<body>
~;

$html .= search_form();

$html .= qq~

<script language="Javascript">
<!--
document.searchform.query.focus();
// -->
</script>

<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><a href="search?help">Help</a> /
<a href="search?form=assisted">Assisted search</a></td>
</tr></table>

</body>
</html>
~;

}

return $html;

}

###

sub display_search_results {

local $handle = shift;
my ($content, $uaresponse, $username) = @_;
my ($response, $request, $query);
local ($html, %folder, %folderid, %message, @folders);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

if  ($form{searchtype} =~ /^assisted$/i) {
  $query = construct_assisted_query(\%form)
} else {
  $query = $form{query};
}

$request = clean EDF::Object("request", \"folder_list");
$request->addChild("searchtype", 3);
$response = $handle->request($request);
$request->DESTROY;

unless ($response->value eq "folder_list") {
  die "Unknown response: " . $response->value . "\n";
}

if ($form{'folders'} eq 'all') {
  foreach (get_folders($response)) {
    push(@folders, (keys %$_)[0]);
  }
} else {
  foreach (get_folders($response)) {
    my $id = (keys %$_)[0];
    push(@folders, $id) if ($_->{$id}->{"subtype"}[0]);
  }
}  

$query =~ s/\n|\r/ /gs;
$query =~ s/^\s+//;
$query =~ s/\s+$//;

$html .= qq~
<html>
<head>
<title>Search results</title>
<link rel=stylesheet type="text/css" href="ua.css">

<script language="Javascript">
<!--

var omess;

function openMessage(mid) {

  if (! document.images["mess" + mid]) {
    return;
  }

  if (omess) { document.images["mess" + omess].src = "images/rm.gif"; }
  document.images["mess" + mid].src = "images/om.gif";
  omess = mid;

  document.images["mess" + mid].parentElement.className = "ra";

}

// -->
</script>

</head>
<body>
~;

my $results = boolean_search($query);

if (defined $results) {

  my @times = ("no messages", "one message", "two messages", "three messages", "four messages", "five messages", "six messages", "seven messages", "eight messages", "nine messages", "ten messages", "eleven messages", "twelve messages");
  my $matches = scalar(@$results);

  $html .= qq~
<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><table width="100%" border="0" cellspacing="0" cellpadding="0" class="title"><tr>
<td>'~ . escape_html($query, 0, 1) . qq~' matched ~ .
($times[$matches] || "$matches messages.") .
qq~.</td>
</tr></table>
<table width="100%" border="0" cellspacing="0" cellpadding="0"><tr>
<td>~;

  if (@$results) {
    $html .= qq~<div class="message"><table border="0" cellspacing="0" cellpadding="0" width="100%">~;
  }

  my $lastfolder;

  foreach my $id (sort { $folder{$a} cmp $folder{$b} || $a <=> $b } @$results) {
    if ($lastfolder ne $folderid{$id}) {
      $html .= qq~<tr>\n<td class="fl"><a href="showfolder?folder=$folderid{$id}" target="messagelist" class="un" onClick="parent.folders.openFolder($folderid{$id})"><img src="$IMAGEDIR/cf.gif" height="13" width="16" border="0" alt="*"> $folder{$id}</a></td>\n</tr>~;
      $lastfolder = $folderid{$id};
    }

    $html .= qq~<tr>\n<td><img src="$IMAGEDIR/blank.gif" width="8" height="13"> <a href="showmessage?folder=$lastfolder&amp;message=$id" target="messages" class="~ .
             ($message{$id}{read}[0]?"ra":"un") .
             qq~" onClick="openMessage($id, false)"><img src="$IMAGEDIR/~ .
             ($message{$id}{read}[0]?"rm":"cm") .
             qq~.gif" height="13" width="16" border="0" name="mess$id" alt="*"> <span class="subj">~ .
             parse_colours(escape_html($message{$id}{subject}[0] || "[no subject]")) .
             qq~</span></a> <span class="auth">(~ . $message{$id}{fromname}[0] .
             qq~)</span> <span class="date">~ . shortParseDate($message{$id}{date}[0]) .
             qq~</span></td>\n</tr>~;
  }

  if (@$results) {
    $html .= qq~</table></div>~
  }

  $html .= qq~</td></tr></table></td></tr></table>~;

  $html .= search_form($query);

  $html .= qq~
<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><a href="search?help">Help</a> /
<a href="search?form=assisted">Assisted search</a></td>
</tr></table>~;

}

return $html;

}

###

sub boolean_search {

local($open, $close);

my $text = shift;

$text =~ s/[\n\r\t\f]+/ /gs;
$text =~ s/^\s*(.*?)\s*$/$1/;
$text =~ s/\s{2,}/ /g;
$text =~ y/\0//d;

my @quoted = ();

while ($text =~ s/(["'])(.*?)\1/"\0" . scalar(@quoted) . "\0"/e) {
  push(@quoted, $2);
}

$text =~ s/\bnot not\b//g;

my @split = map { s/^\s+//; s/\s+$//; s/\0(.*?)\0/$quoted[$1]/g; $_; } split(/(\(|\)|\band not\b|\bor not\b|\bxor not\b|\band\b|\bor\b|\bnot\b|\bxor\b)/i, $text);

my @arguments = ();
my @values = ();

while (@split) {
 my $results = _search(shift(@split));
 return undef unless (defined($results));

 push(@values, $results);
 push(@arguments, shift(@split));
}

#print "VALUES: ", join(" ", map {@$_} @values), "\n";
#print "ARGS  : ", join(" ", map {@$_} @arguments), "\n";

while (1) {

# find innermost set of rightmost sets of brackets 

  for ($open = $#arguments; $open > -1; $open--) {
    last if $arguments[$open] eq "(";
  }

  last unless ($open > -1);

  for ($close = $open + 1; $close <= $#arguments; $close++) {
    last if $arguments[$close] eq ")";
  }

  return search_error("Mismatched parentheses.") unless ($close <= $#arguments );
#  return search_error("Mismatched parentheses $open $arguments[$open]") unless ($close <= $#arguments );

  my @b_args = splice(@arguments, $open + 1, $close - $open - 1);
  my @b_vals = splice(@values, $open + 1, $close - $open);

INNER:
  while (1) {

    $return = boolean_process(shift(@b_vals), shift(@b_args), shift(@b_vals));
    return undef unless (defined($return));

    if (@b_vals || @b_args) {
      unshift(@b_vals, $return);
    } else {
      splice(@values, $open, 2, $return); # place value back in argument list
      last INNER;
    }

  }

  splice(@arguments, $open,  2); # remove brackets

}

while (1) {

  $return = boolean_process(shift(@values), shift(@arguments), shift(@values));
  return undef unless (defined($return));

  if (@values || @arguments) {
    unshift(@values, $return);
  } else {
    $result = $return;
    last;
  }

}

return $result;

}

###

sub _search {

my $text = shift;
my @matches = ();
my @list;
my $foldername;
my $response;
my $request;

$text =~ s/\n|\r/ /gs;
$text =~ s/^\s*(.*?)\s*$/$1/;
$text =~ s/\s{2,}/ /g;

$request = clean EDF::Object("request", \"message_list");
$request->addChild("searchtype", 1);
$request->addChild("folderid");

if ($text =~ /^(message|msg):(.*)$/i) {

  my ($command, $message) = ($1, $2);

  return search_error("$command: needs a numerical argument.") if ($message =~ /\D/) ;

  $request->addChild("messageid", $2);

} elsif ($text =~ /^(from|to|user):(.*)$/i) {

  my ($command, $user) = ($1, $2);

  my $userid = id_user($user);

  return search_error("There is no user called '$user'") unless ($userid);

  if ($command =~ /from|user/i) {
    $request->addChild("fromid", $userid);
  }

  if ($command =~ /to|user/i) {
    $request->addChild("toid", $userid);
  }

} else {

  $request->addChild("keyword", \"$text");

}

foreach $folderid (@folders) {

  print "Searching $folderid\n";

  $request->child("folderid")->value($folderid);
  $request->parent;

  $response = $handle->request($request);

  @list = ();

  if ($response->child("message")) {
    do {
      push(@list, { $response->value => { $response->elements } } );
    } while ($response->next("message"));
  }

  if ($response->first("foldername")) {
    $foldername = $response->value;
  } else {
    next;
  }

  foreach my $element (@list) {

    my($id, $hash) = each %$element;
    push(@matches, $id);

    $message{$id} = { %$hash };

    $folder{$id}   = $foldername;
    $folderid{$id} = $folderid
  }

  $response->DESTROY;

}

$request->DESTROY;

#print join("\t", @matches), "\n";

return \@matches;

}

###

sub _all_messages {

my @list = ();
my @all = ();

my $folderid;

my $request = clean EDF::Object("request", \"message_list");
$request->addChild("searchtype", 0);
$request->addChild("folderid");

foreach $folderid (@folders) {
  $request->child("folderid")->value($folderid);
  $request->parent;
  $response = $handle->request($request);

  @list = search_messages($response);

  if ($response->first("foldername")) {
    $foldername = $response->value;
  } else {
    next;
  }

  foreach my $element (@list) {
    my($id, $hash) = each %$element;
    push(@all, $id);

    $message{$id} = { %$hash };

    $folder{$id}  = $foldername;
    $folderid{$id} = $folderid
  }

  $response->DESTROY;

}

$request->DESTROY;

#print join("\t", @all);

return @all;

}

###

sub boolean_process {

my ($pre, $arg, $post) = @_;

#print "\t\t!", join("-", $pre, $arg, $post), "\n";

return                                                                      if (! defined($pre) && ! defined($arg)   && ! defined($post));
return search_error("argument without following value")                     if (  defined($pre) &&   defined($arg)   && ! defined($post));
return search_error("this cannot happen -- two values without an argument") if (  defined($pre) && ! defined($arg)   &&   defined($post));
return $pre                                                                 if (  defined($pre) && ! defined($arg)   && ! defined($post));
return search_error("argument without any values")                          if (! defined($pre) &&   defined($arg)   && ! defined($post));
return search_error("$arg is not a unary operator")                         if (! defined($pre) &&   ($arg ne "not")                    );

#print "\t\t\t\t$arg\n";
#print "PRE : ", join("\t", @$pre), "\n\n";
#print "POST: ", join("\t", @$post), "\n\n";

$arg =~ y/ //d;
$arg = lc($arg);
return &{"boolean_$arg"}($pre, $post);

}

###

sub boolean_or {

my($a, $b) = @_;
my %or;

foreach (@$a, @$b) { $or{$_}++ }

return [ keys %or ];

}

###

sub boolean_xor {

my($a, $b) = @_;
my %xor;

foreach (@$a, @$b) { $xor{$_}++ && delete $xor{$_} }

#print "XOR\t:", scalar(@$a), ":\t:", scalar(@$b), ":\t:", scalar(keys %xor), ":\n";

return [ keys %xor ];

}

###

sub boolean_and {

my($a, $b) = @_;
my %and;
my %or;

foreach (@$a, @$b) { $or{$_}++ && $and{$_}++ }

return [ keys %and ];

}

###

sub boolean_not {

my $b;
(undef, $b) = @_;

@all_messages = _all_messages();

return boolean_xor(\@all_messages, $b);

}

###

sub boolean_andnot {

my($a, $b) = @_;

return boolean_and($a, boolean_not(undef, $b));

}

###

sub boolean_ornot {

my($a, $b) = @_;

return boolean_or($a, boolean_not(undef, $b));

}

###

sub boolean_xornot {

my($a, $b) = @_;

return boolean_xor($a, boolean_not(undef, $b));

}

###

sub search_error {

my $message = shift;

$html .= qq~
<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td>Search error: $message</td>
</tr></table>
</body>
</html>
~;

return undef;

}

###

sub search_messages {

my $edf = shift;

local @::messages = ();

if ($edf->child("message")) {
  search_messagesR($edf);
}

return @::messages;

}

###

sub search_messagesR {

my $edf = shift;

do {

  push(@::messages, { $edf->value => { $edf->elements } } );

  if ($edf->child("message")) {
    search_messagesR($edf);
    $edf->parent;
  }

} while ($edf->next("message"));


return;

}

###

sub id_user {

my $username = shift;
my $request;
my $response;
my $userid;

$request = clean EDF::Object("request", \"user_list");
$request->addChild("searchtype", 0);
$request->addChild("name", \$username);
$response = $handle->request($request);

$userid = $response->value if ($response->first("user"));

return $userid;

}

###

sub instructions {

return qq~

<html>
<head>
<title>Search help</title>
<link rel=stylesheet type="text/css" href="ua.css">
</head>
<body>

<p class="subj">You can search 
using boolean expressions and use parentheses to group boolean phrases. 
You must use &quot; or ' to group phrases if using boolean expressions. </p>

<table border="0" width="100%" cellpadding="0" cellspacing="0" class="headers"><tr>
<td>Boolean keywords:</td>
</tr><tr>
<td><div class="message"><table border="0" cellpadding="0" cellspacing="0" class="fl"><tr>
<td><b>and</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td>shell&nbsp;<b>AND</b>&nbsp;unix finds messages containing both the word shell and the word unix.</td>
</tr><tr>
<td><b>or</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td>shell&nbsp;<b>OR</b>&nbsp;unix finds messages containing either the word shell or the word unix. Each message may contain both words, but not necessarily.</td>
</tr><tr>
<td><b>xor</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td>shell&nbsp;<b>XOR</b>&nbsp;unix finds messages containing either the word shell or the word unix, excluding messages containing both words.</td>
</tr><tr>
<td><b>not</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td>Excludes messages containing the specified word or phrase.</td>
</tr><tr>
<td><b>(&nbsp;)</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td>Use parentheses to group boolean phrases. <b>(</b>shell&nbsp;AND&nbsp;unix<b>)</b> AND <b>(</b>zsh&nbsp;OR&nbsp;csh<b>)</b> finds messages with the words 'shell and unix and zsh' or 'shell and unix and csh' or both.</td>
</tr></table></div></td>
</tr></table>
<br>
<table border="0" width="100%" cellpadding="0" cellspacing="0" class="headers"><tr>
<td>Extended search keywords:</td>
</tr><tr>
<td><div class="message"><table border="0" cellpadding="0" cellspacing="0" class="fl"><tr>
<td><b>message:message-id</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td>finds message with id <b>message-id</b>.</td>
</tr><tr>
<td><b>to:username</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td>finds messages sent to <b>username</b>.</td>
</tr><tr>
<td><b>from:username</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td>finds messages sent by <b>username</b>.</td>
</tr><tr>
<td><b>user:username</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td>finds messages sent to or by <b>username</b>.</td>
</tr></table></div></td>
</tr></table>
<br>
<table border="0" width="100%" cellpadding="0" cellspacing="0" class="headers"><tr>
<td>Examples:</td>
</tr><tr>
<td><div class="message"><table border="0" cellpadding="0" cellspacing="0" class="fl"><tr>
<td><b>slashdot</b></td>
</tr><tr>
<td><b>the simpsons</b></td>
</tr><tr>
<td><b>ua and user:quax</b></td>
</tr><tr>
<td><b>message:184563</b></td>
</tr><tr>
<td><b>searhc and (to:sirhc or to:quax)</b></td>
</tr><tr>
<td><b>"ua client" or "ua2 client"</b></td>
</tr><tr>
<td><b>from:"the mountie"</b></td>
</tr></table></div></td>
</tr></table>
<br>
<table border="0" width="100%" cellpadding="0" cellspacing="0" class="headers"><tr>
<td>Notes:</td>
</tr><tr>
<td>
<div class="message"><table border="0" cellpadding="0" cellspacing="0" class="fl"><tr>
<td>Usernames containing spaces must be written: "username"</td>
</tr><tr>
<td>Search 
results are case-insensitive substring matches.</td>
</tr></table></div>
</td>
</tr></table>

~ . search_form() . qq~

<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><a href="search?form=assisted">Assisted search</a></td>
</tr></table>

</body>
</html>
~;

}

###

sub search_form {

my $value = shift;
$value = escape_html($value, 0, 1);

return qq~
<form method="post" action="results" name="searchform">
<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td>Search request:</td>
</tr><tr>
<td><div class="message"><input type="text" name="query" value="$value" size="40" style="width: 100%" class="fl"><br><span class="fl">
From&nbsp;<select name="folders" class="fl" style="font-weight: bold">
<option value="subscribed">subscribed</option>
<option value="all">all</option>
</select>&nbsp;folders</span></div></td>
</tr>

<tr>
<td class="buttonhole"><input type="submit" name="Submit" value="Search" class="button"></td>
</tr></table>
</form>
~;

}

###

sub display_assisted_search_form {

my $html;

$html = qq~
<html>
<head>
<title>Search</title>
<link rel=stylesheet type="text/css" href="ua.css">
</head>
<body>
<form method="post" action="results" name="searchform">
<input type="hidden" name="searchtype" value="assisted">
<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td>Find messages:</td>
</tr><tr>
<td><div class="message"><table border="0" cellpadding="0" cellspacing="0" class="fl"><tr>
<td>with <b>all</b> the words</td>
<td><b>&nbsp;:&nbsp;</b></td>
<td><input type="text" name="withall" value="" size="40" class="fl"></td>
</tr><tr>
<td>with <b>any</b> of the words</td>
<td><b>&nbsp;:&nbsp;</b></td>
<td><input type="text" name="withany" value="" size="40" class="fl"></td>
</tr><tr>
<td>with the <b>exact phrase</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td><input type="text" name="withphrase" value="" size="40" class="fl"></td>
</tr><tr>
<td><b>without any</b> of the words</td>
<td><b>&nbsp;:&nbsp;</b></td>
<td><input type="text" name="withoutall" value="" size="40" class="fl"></td>
</tr><tr>
<td><b>without</b> the <b>exact phrase</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td><input type="text" name="withoutphrase" value="" size="40" class="fl"></td>
</tr><tr>
<td>Sent&nbsp;<select name="byto" class="fl" style="font-weight: bold">
<option value="to">to</option>
<option value="from">by</option>
<option value="user" selected>to or by</option>
</select></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td><input type="text" name="bytouser" value="" size="40" class="fl"></td>
</tr><!-- <tr>
<td>Sent <b>before</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td><input type="text" name="before" value="" size="40" class="fl"></td>
</tr><tr>
<td>Sent <b>after</b></td>
<td><b>&nbsp;:&nbsp;</b></td>
<td><input type="text" name="after" value="" size="40" class="fl"></td>
</tr></table></div></td>
</tr> -->

<tr>
<td colspan="3">From&nbsp;<select name="folders" class="fl" style="font-weight: bold">
<option value="subscribed">subscribed</option>
<option value="all">all</option>
</select>&nbsp;folders</td>
</tr>

</table></div></td>
</tr><tr>
<td class="buttonhole"><input type="submit" name="Submit" value="Search" class="button"></td>
</tr></table>
</form>

<script language="Javascript">
<!--

document.searchform.withall.focus();

// -->
</script>

<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><a href="search?help">Help</a> /
<a href="search">Search</a></td>
</tr></table>
</body>
</html>
~;

return $html;

}

###

sub construct_assisted_query {

my $form = shift;
my @query;

push (@query, "("     . join(" AND ", map { qq~'$_'~ } split(' ', $form->{'withall'}) ) .    ")") if ($form->{'withall'}       =~ /\S/);
push (@query, "("     . join(" OR ",  map { qq~'$_'~ } split(' ', $form->{'withany'}) ) .    ")") if ($form->{'withany'}       =~ /\S/);
push (@query, "'"     .                                           $form->{'withphrase'} .    "'") if ($form->{'withphrase'}    =~ /\S/);
push (@query, "NOT (" . join(" OR ",  map { qq~'$_'~ } split(' ', $form->{'withoutall'}) ) . ")") if ($form->{'withoutall'}    =~ /\S/);
push (@query, "NOT '" .                                           $form->{'withoutphrase'} . "'") if ($form->{'withoutphrase'} =~ /\S/);

push (@query, "$form->{'byto'}:'$form->{'bytouser'}'"                                           ) if ($form->{'bytouser'}      =~ /\S/);

return join (" AND ", @query);

}

###
1;

