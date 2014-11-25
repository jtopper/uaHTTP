### uaHTTP request processing functions ###

### Functions ###

sub process_request {

local ($connect, $http_request, $handle, $uaresponse, $username, $override) = @_;
my ($type, $status, $redirect);
my $cache = 0;
my $refresh = undef;

$http_request->uri =~ /^(.*?)(\?(.*))?$/;

my ($file, $input) = ($1, $3);

if ($file eq "/") {
  $file = "index.html";
}

local $headers = new HTTP::Headers (
	Server		=> "uaHTTP/$VERSION EDF.pm/$EDFPMVERSION",
);

if ($override) {

  foreach ($override) {
    m#^authorisation$#	&& do { $response = &authorise_content; $status = RC_UNAUTHORIZED; $headers->www_authenticate('Basic realm="uaHTTP"'); last };
  }

} else {

  my %form = &parse_input($http_request->content || $input);

  foreach ($file) {

    local $SIG{__DIE__} = \&DieHandler;

    $uaresponse->root if ($uaresponse);

    m#^/folders$#	&& do { $response = &display_folders($handle, \%form, $uaresponse, $username); $refresh = 120;				last };
    m#^/showfolder$#	&& do { $response = &display_folder($handle, \%form, $uaresponse, $username); 						last };
    m#^/showmessage$#	&& do { $response = &display_message($handle, \%form, $uaresponse, $username);						last };
    m#^/postmessage$#	&& do { $response = &display_posting($handle, \%form, $uaresponse, $username);						last };
    m#^/addmessage$#	&& do { $response = &add_message($handle, \%form, $uaresponse, $username);						last };
    m#^/notemessage$#	&& do { $response = &display_annotation($handle, \%form, $uaresponse, $username);					last };
    m#^/addnote$#	&& do { $response = &add_annotation($handle, \%form, $uaresponse, $username);						last };
    m#^/deletemessage$#	&& do { $response = &delete_message($handle, \%form, $uaresponse, $username);						last };
    m#^/holdmessage$#	&& do { $response = &hold_message($handle, \%form, $uaresponse, $username);						last };
    m#^/holdthread$#	&& do { $response = &hold_thread($handle, \%form, $uaresponse, $username);						last };
    m#^/displaymove$#	&& do { $response = &display_move($handle, \%form, $uaresponse, $username);						last };
    m#^/movemessage$#	&& do { $response = &move_message($handle, \%form, $uaresponse, $username);						last };
    m#^/announcements$#	&& do { $response = &display_announcements($handle, \%form, $uaresponse, $username); $refresh = 60;			last };
    m#^/folderinfo$#	&& do { $response = &display_folderinfo($handle, \%form, $uaresponse, $username);					last };
    m#^/userinfo$#	&& do { $response = &display_userinfo($handle, \%form, $uaresponse, $username);						last };
    m#^/userlogout$#	&& do { $response = &user_logout($handle, \%form, $uaresponse, $username);						last };
    m#^/wholist$#	&& do { $response = &display_wholist($handle, \%form, $uaresponse, $username); $refresh = 120;				last };
    m#^/search$#	&& do { $response = &display_search_form($handle, \%form, $uaresponse, $username); 					last };
    m#^/results$#	&& do { $response = &display_search_results($handle, \%form, $uaresponse, $username); 					last };
    m#^/banner$#	&& do { $response = &display_banner($handle, \%form, $uaresponse, $username); 						last };
    m#^/vote$#		&& do { $response = &process_vote($handle, \%form, $uaresponse, $username);						last };
    m#^/usermessage$#	&& do { $headers->header(Location => &change_message($handle, \%form, $uaresponse, $username)); $status = RC_FOUND;	last };
    m#^/displaypage$#	&& do { $response = &display_page($handle, \%form, $uaresponse, $username);						last };
    m#^/sendpage$#	&& do { $response = &send_page($handle, \%form, $uaresponse, $username);						last };
    m#^/index$#		&& do { &unset_nocontact($handle, undef, $uaresponse); ($response, $type, $status) = &get_file('indexjs.html');		last };
    m#^/quickjump$#	&& do { $response = &quickjump($handle, \%form, $uaresponse, $username);						last };
    m#^/description$#	&& do { $response = &change_description($handle, \%form, $uaresponse, $username);					last };
    m#^/infofile$#	&& do { $response = &change_infofile($handle, \%form, $uaresponse, $username);						last };

    m#^/catchup$#	&& do { &catchup_messages($handle, \%form, $uaresponse, $username); $file = "/showfolder";				redo };
    m#^/subscribe$#	&& do { &subscribe($handle, \%form, $uaresponse, $username); $file = "/showfolder";					redo };

			   do { ($response, $type, $status) = &get_file($file); $cache = 1;							last };
  }

}

send_reply([ $response, $type, $status, $refresh, $headers, $cache, $http_request, $connect, $username ]);

print "Reply sent: $$\n" if ($DEBUG);

return;

}

###

sub DieHandler {

my $message = shift;

my $response = qq~
<html>
<head>
<title>uaHTTP Error</title>
<link rel=stylesheet type="text/css" href="ua.css">
</head>

<body>

<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td>uaHTTP Error</td>
</tr><tr>
<td><div class="message"><br>$message<br></div></td>
</tr></table>

</body>
</html>
~;

send_reply([ $response, 'html', RC_GONE, undef, $headers, undef, $http_request, $connect, $username ]);

}

###

sub send_reply {

my($response, $type, $status, $refresh, $headers, $cache, $http_request, $connect, $username) = @{$_[0]};

$type   ||= "html";
$status ||= RC_OK;

$response = "" unless (defined $response);

my %content_type = (
	css	=>	'text/css',
	html	=>	'text/html; charset=utf-8',
	gif	=>	'image/gif',
	jpg	=>	'image/jpeg',
	js	=>	'text/javascript',
);

if ($refresh) {
#  $headers->header(Refresh       => $refresh);
  $refresh *= 1000;
  $response =~ s#</head>#<script language="JavaScript">\n<!--\nsetTimeout("location.reload(1)", $refresh);\n// -->\n</script>\n</head>\n#i;
}


if ($type =~ /css|html|js/) {

  foreach (split(/[ ,]+/, $http_request->header("Accept-Encoding"))) {

#    if (/^deflate$/) {
#      my $deflate = deflateInit();
#      $response  = $deflate->deflate(\$response) . $deflate->flush;
#      $headers->header(Content_Encoding => $_);
#      last;
#    }

    if (/^(?:gzip|x-gzip)$/) {
      $response = Compress::Zlib::memGzip(\$response);
      $headers->header(Content_Encoding => $_);
      last;
    }

  }

}

#my $ETag = join("", q/"/, MD5->hexhash($response), q/"/);

$headers->date(time);
$headers->header(Content_Type   => $content_type{$type});
$headers->header(Content_Length => length($response));
#$headers->header(ETag           => $ETag);

if ($cache) {
  $headers->expires(time + 24 * 60 * 60);
  $headers->header(Cache_Control => 'max-age=86400');
} else {
  $headers->header(Pragma        => 'no-cache');
  $headers->header(Cache_Control => 'private, no-cache, max-age=0');
  $headers->expires(time);
}

$connect->send_status_line($status);

&write_log($http_request, $connect, $username, $status, length($response));

print $connect $headers->as_string;
print $connect "\n";
print $connect $response;

return 1;

}

###

sub get_file {

my $file = shift;
my $response;

my $openfile = "$SERVER_ROOT/$file";

$openfile =~ s#//+#/#g;
$openfile =~ s#\.\.+##g;

unless(open(FILE, "< $openfile")) {

  $response .= qq~
<html>
<head>
<title>File not found</title>
</head>

<body>
<h1>404 File not found</h1>
<p>
You asked for $file. Unfortunately it does not exist. ($openfile)
</p>
</body>
</html>
~;

  return ($response, "html", RC_NOT_FOUND);

}

binmode(FILE);

{
  local $/ = undef;
  $response = <FILE>;
}

$file =~ /\.(.*?)$/;

my $type = $1;

return ($response, $type, RC_OK);

}

###

sub authorise_content {

return qq~
<html>
<head>
<title>Login invalid</title>
</head>

<body>
<h1>Login invalid</h1>
<p>Your username and password are invalid.</p>
</body>
</html>
~;

}

###
1;

