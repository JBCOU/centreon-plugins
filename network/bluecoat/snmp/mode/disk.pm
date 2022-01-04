#
# Copyright 2022 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package network::bluecoat::snmp::mode::disk;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments =>
                                { 
                                  "warning:s"      => { name => 'warning' },
                                  "critical:s"     => { name => 'critical' },
                                });
                                
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
    
    if (($self->{perfdata}->threshold_validate(label => 'warning', value => $self->{option_results}->{warning})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong warning threshold '" . $self->{option_results}->{warning} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical', value => $self->{option_results}->{critical})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong critical threshold '" . $self->{option_results}->{critical} . "'.");
        $self->{output}->option_exit();
    }
}

sub run {
    my ($self, %options) = @_;
    $self->{snmp} = $options{snmp};
    
    my $disk_num = 1;
    my $result = $self->{snmp}->get_table(oid => '.1.3.6.1.4.1.3417.2.4.1.1.1');
    my $oid_deviceUsageName = '.1.3.6.1.4.1.3417.2.4.1.1.1.3';
    my $oid_deviceUsagePercent = '.1.3.6.1.4.1.3417.2.4.1.1.1.4';
    
    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$result})) {
        next if ($oid !~ /^$oid_deviceUsageName\.(\d+)/);
        my $instance = $1;
        next if ($result->{$oid} !~ /^DISK/i);
        
        my $disk_usage = $result->{$oid_deviceUsagePercent . '.' . $instance};
        my $exit = $self->{perfdata}->threshold_check(value => $disk_usage, threshold => [ { label => 'critical', exit_litteral => 'critical' }, { label => 'warning', exit_litteral => 'warning' } ]);
        $self->{output}->output_add(severity => $exit,
                                    short_msg => sprintf("Disk $disk_num usage is %.2f%%", $disk_usage));
        $self->{output}->perfdata_add(label => 'disk_' . $disk_num, unit => '%',
                                      value => sprintf("%.2f", $disk_usage),
                                      warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning'),
                                      critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical'),
                                      min => 0, max => 100);
        $disk_num++;
    }
    
    if ($disk_num == 1) {
        $self->{output}->add_option_msg(short_msg => "No disk information found...");
        $self->{output}->option_exit();
    }
    
    $self->{output}->display();
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Check disks usage.

=over 8

=item B<--warning>

Threshold warning in percent.

=item B<--critical>

Threshold critical in percent.

=back

=cut
