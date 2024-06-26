#!/usr/bin/env perl
use strict;
use warnings;
use GD;

# width and height of keyboard in pixels.
my $w = 1366;
my $h = 168;
 
# create a new image
my $im = GD::Image->new($w, $h);
 
# allocate some colors
my $white = $im->colorAllocate(255,255,255);
my $black = $im->colorAllocate(0,0,0);       
 
# make the background transparent and interlaced
$im->interlaced('true');

my $t1 = $w/52; # 52 white keys.
for(my $i = 0; $i < 52; $i++) {
	$im->rectangle($i * $t1, 0, ($i+1)*$t1, $h, $black);
}

# draw the first black keys.  width of black key = 2 * whitekey / 3, height = 0.6 * whitekey
my $t2 = $t1 * 0.6667;
$im->filledRectangle($t1 * 0.667, 0, $t1 * 0.667 * 2, $h * 0.6, $black);


my $start = $t1 * 2;

my @blackkey_id = ( 0, 1, 3, 4, 5 );
for(my $i =0; $i < 7; $i++) { # draw the left 35 black keys.
	foreach(@blackkey_id) {
		my $offset = 2 + $i * 7 + $_;
		$im->filledRectangle( ($offset + 0.667) * $t1, 0, ($offset + 0.667 * 2) * $t1, $h * 0.6, $black);
	}
}

open my $fh, ">",  "./piano3.png" or die $!;
binmode $fh;
print $fh $im->png;
close $fh;
