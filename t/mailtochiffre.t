#!/usr/bin/env perl
use Mojo::Base -strict;
use Mojolicious::Lite;
use Mojo::ByteStream 'b';
use Test::Mojo;
use Test::More;
use Mojo::DOM;
use Mojo::URL;

$|++;

use lib '../lib';

my $t = Test::Mojo->new;
my $app = $t->app;

$app->plugin('TagHelpers::MailToChiffre' => {
  pattern_rotate => 8
});

my $css = $app->mail_to_chiffre_css;
ok($css =~ m/^a\[onclick\$='return ([a-zA-Z]+?)\(this,false\)'/, 'css is as expected');
my $method_name = $1;

my $js = $app->mail_to_chiffre_js;
like($js, qr/^function $method_name\(/, 'js is as expected');
like($js, qr/\(2,3\)/, 'pattern shift is as expected');

$css = $app->mail_to_chiffre_css;
ok($css =~ m/^a\[onclick\$='return $method_name\(this,false\)'/, 'css is still as expected');

sub url_to_sort {
  my $url = shift;
  my $s = $url->scheme .':';
  $s .= $url->path;
  my $x = $url->query->to_hash;
  $s .= '?' . join('&' , sort map( $_ . '=' . (ref $x->{$_} ? join(',', @{$x->{$_}}) : $x->{$_}), keys %$x ) );
};

$app->routes->get('/test')->mail_to_chiffre(
  cb => sub {
    my $c = shift;
    return $c->render(text => 'Found: ' . url_to_sort($c->stash('mail_to_chiffre')));
  }
);

ok(Mojo::DOM->new('<a href="/test/GYXvEWFdOwDlxOZSDU/-40n-17-53-52-40-45-55-26-46-38-49?sid=-55-24-38-44-53" rel="nofollow" onclick="return fNiNhmFtmdFXGZLsrVeoyGI(this,false)"><span>su.oicilojos</span><span>UDSZOxlDwOdFWEvXYG</span>norka</a>')->at('a'), 'Mojo::DOM works');

ok(Mojo::DOM->new(b('<a href="/test/GYXvEWFdOwDlxOZSDU/-40n-17-53-52-40-45-55-26-46-38-49?sid=-55-24-38-44-53" rel="nofollow" onclick="return fNiNhmFtmdFXGZLsrVeoyGI(this,false)"><span>su.oicilojos</span><span>UDSZOxlDwOdFWEvXYG</span>norka</a>'))->at('a'), 'Mojo::DOM works with bytestreams');


my $chiffre_as_expected = sub {
  my $t = shift;
  my $address = shift;
  my $desc = pop if @_ % 2;
  my %param = @_;
  my $c = delete $param{cb};

  $desc ||= "chiffre as expected";
  local $Test::Builder::Level = $Test::Builder::Level + 1;

  # Create anchor tag
  my $a = $app->mail_to_chiffre($address, %param);
  ok($a, 'mail_to_chiffre returns a string');

  # Get the url
  my $span = Mojo::DOM->new($a);

  if ($span->at('a span')) {
    my $mail = b($span->at('a span:nth-child(1)')->text . '@' . $span->at('a')->text);
    $mail = $mail->split('')->reverse->join('')->to_string;

    is($mail, $address, 'CSS obfuscation as expected');
  }
  else {
    ok(0, 'The css obfuscation didn\'t work');
  };

  my $href;
  my $anchor = $span->at('a');
  ok($a, 'Found anchor');
  if ($anchor) {
    $href = $anchor->attr('href');
  }
  else {
    diag "Unable to find anchor in [$a]"
  };

  like($href, qr!^/test/[-a-zA-Z0-9]+?/[-a-zA-Z0-9]+?\?!, $desc . ' (URL)');
  like($href, qr!sid=[-a-zA-Z0-9]+?!, $desc . ' (SID)');

  foreach (qw/to cc bcc/) {
    if (exists $param{$_}) {
      like($href, qr!$_=[-a-zA-Z0-9]+?(?:\&|$)!, $desc . ' (' . $_ . ')');
    };
  };

  my $url = Mojo::URL->new;
  $url->scheme('mailto');
  $url->path($address);
  $url->query(%param);
  my $norm = url_to_sort($url);

  $t->get_ok($href)->content_is('Found: ' . $norm)
    ->header_is('X-Robots-Tag' => 'noindex,nofollow');

  $t->success( ok(1, $desc . ' (' . $norm . ')') );
};

$t->$chiffre_as_expected('akron@sojolicio.us', 'Chiffre 1');
$t->$chiffre_as_expected('äkrön@sojolicio.us', 'Chiffre 2');
$t->$chiffre_as_expected('akron@sojolicio.us', subject => 'Hi!', 'Chiffre 3');
$t->$chiffre_as_expected('akron@sojolicio.us', to => 'ä@test.com', 'Chiffre 4');
$t->$chiffre_as_expected('akron@sojolicio.us', cc => 'ä@test.com', 'Chiffre 5');
$t->$chiffre_as_expected('akron@sojolicio.us', bcc => 'ä@test.com', 'Chiffre 6');
$t->$chiffre_as_expected('akron@sojolicio.us', subject => 'Hi!', to => 'ä@test.com', 'Chiffre 7');
$t->$chiffre_as_expected('akron@sojolicio.us', subject => 'Hi!', to => 'ä@test.com', bcc => ['hihi@test.com','ü@wow.com'], 'Chiffre 7');
$t->$chiffre_as_expected('akron@sojolicio.us', subject => 'Hi!', cb => sub { 'test' }, 'Chiffre 7');


# New start
$t = Test::Mojo->new;
$app = $t->app;

$method_name = 'deobfuscate';

$app->plugin('TagHelpers::MailToChiffre' => {
  pattern_rotate => 9,
  method_name => $method_name
});

$css = $app->mail_to_chiffre_css;
ok($css =~ m/^a\[onclick\$='return $method_name\(this,false\)'/, 'css is as expected');

$js = $app->mail_to_chiffre_js;
like($js, qr/^function $method_name\(/, 'js is as expected');
like($js, qr/\(3,2\)/, 'pattern shift is as expected');

$app->routes->get('/testnew')->mail_to_chiffre(
  cb => sub {
    my $c = shift;
    return $c->render(text => 'Found: ' . url_to_sort($c->stash('mail_to_chiffre')));
  }
);

$t->$chiffre_as_expected('akron@sojolicio.us', 'Chiffre 1');
$t->$chiffre_as_expected('akron@sojolicio.us', subject => 'Hi!', to => 'ä@test.com', bcc => ['hihi@test.com','ü@wow.com'], 'Chiffre 7');
$t->$chiffre_as_expected('akron@sojolicio.us', subject => 'Hi!', cb => sub { 'test' }, 'Chiffre 7');

done_testing;

__END__
