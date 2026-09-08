#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin);

my ($src_w, $src_h, $width, $height, $win) = (320, 240, 640, 480, 16);
open my $input, '<', "$Bin/photo_input.hex" or die "photo_input.hex: $!";
my @source = map { s/\s+//g; hex($_) } <$input>;
close $input;
die "photo_input.hex pixel count is not 76800\n" unless @source == $src_w * $src_h;

my @upscaled = map {
    my $index = $_;
    $source[int($index / $width / 2) * $src_w +
            int(($index % $width) / 2)]
} 0 .. $width * $height - 1;

# The delayed sync identifies the oldest (top-left) pixel held by the RTL
# line buffers.  Therefore the expected pixel is the average of the 16x16
# window starting at (x,y), rather than the window ending there.  Pixels past
# the 640x480 active region are blank and contribute zero, just as in VGA.
my (@column_r, @column_g, @column_b, @result);
for (my $y = $height - 1; $y >= 0; $y--) {
    for my $x (0 .. $width - 1) {
        my $pixel = $upscaled[$y * $width + $x];
        $column_r[$x] = ($column_r[$x] // 0) + (($pixel >> 8) & 15);
        $column_g[$x] = ($column_g[$x] // 0) + (($pixel >> 4) & 15);
        $column_b[$x] = ($column_b[$x] // 0) + ($pixel & 15);
        if ($y + $win < $height) {
            my $old = $upscaled[($y + $win) * $width + $x];
            $column_r[$x] -= ($old >> 8) & 15;
            $column_g[$x] -= ($old >> 4) & 15;
            $column_b[$x] -= $old & 15;
        }
    }

    my ($sum_r, $sum_g, $sum_b) = (0, 0, 0);
    for (my $x = $width - 1; $x >= 0; $x--) {
        $sum_r += $column_r[$x];
        $sum_g += $column_g[$x];
        $sum_b += $column_b[$x];
        if ($x + $win < $width) {
            $sum_r -= $column_r[$x + $win];
            $sum_g -= $column_g[$x + $win];
            $sum_b -= $column_b[$x + $win];
        }
        $result[$y * $width + $x] = (int($sum_r / 256) << 8) |
                                           (int($sum_g / 256) << 4) |
                                            int($sum_b / 256);
    }
}

open my $output, '>', "$Bin/gaussian_rtl_golden.hex" or die "output: $!";
printf {$output} "%03x\n", $_ for @result;
close $output;
