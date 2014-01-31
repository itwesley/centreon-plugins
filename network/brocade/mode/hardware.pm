################################################################################
# Copyright 2005-2013 MERETHIS
# Centreon is developped by : Julien Mathis and Romain Le Merlus under
# GPL Licence 2.0.
# 
# This program is free software; you can redistribute it and/or modify it under 
# the terms of the GNU General Public License as published by the Free Software 
# Foundation ; either version 2 of the License.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with 
# this program; if not, see <http://www.gnu.org/licenses>.
# 
# Linking this program statically or dynamically with other modules is making a 
# combined work based on this program. Thus, the terms and conditions of the GNU 
# General Public License cover the whole combination.
# 
# As a special exception, the copyright holders of this program give MERETHIS 
# permission to link this program with independent modules to produce an executable, 
# regardless of the license terms of these independent modules, and to copy and 
# distribute the resulting executable under terms of MERETHIS choice, provided that 
# MERETHIS also meet, for each linked independent module, the terms  and conditions 
# of the license of that module. An independent module is a module which is not 
# derived from this program. If you modify this program, you may extend this 
# exception to your version of the program, but you are not obliged to do so. If you
# do not wish to do so, delete this exception statement from your version.
# 
# For more information : contact@centreon.com
# Authors : Quentin Garnier <qgarnier@merethis.com>
#
####################################################################################

package network::brocade::mode::hardware;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use centreon::plugins::misc;

my %operational_status_ex = (
    1 => ["switch operational status is online", 'OK'], 
    2 => ["switch operational status is offline", 'WARNING'], 
    3 => ["switch operational status is testing", 'WARNING'], 
    4 => ["switch operational status is faulty", 'CRITICAL'], 
);
my %sensor_type_map = (
    1 => {name => 'temperature', unit => 'C' },
    2 => {name => 'fan', unit => 'rpm' },
    3 => {name => 'power-supply', unit => undef }, # No voltage value available
);
my %sensor_status = (
    1 => ["%s sensor '%s' is unknown", 'UNKNOWN'], 
    2 => ["%s sensor '%s' is faulty", 'CRITICAL'], 
    3 => ["%s sensor '%s' is below-min", 'WARNING'], 
    4 => ["%s sensor '%s' is nominal", 'OK'], 
    5 => ["%s sensor '%s' is above-max", 'WARNING'], 
    6 => ["%s sensor '%s' is absent", 'WARNING'], 
);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                { 
                                });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub run {
    my ($self, %options) = @_;
    # $options{snmp} = snmp object
    $self->{snmp} = $options{snmp};
    
    my $oid_swFirmwareVersion = '.1.3.6.1.4.1.1588.2.1.1.1.1.6.0';
    my $oid_swOperStatus = '.1.3.6.1.4.1.1588.2.1.1.1.1.7.0';
    my $result = $self->{snmp}->get_leef(oids => [$oid_swFirmwareVersion, $oid_swOperStatus], nothing_quit => 1);
    
    $self->{output}->output_add(severity => ${$operational_status{$result->{$oid_swOperStatus}}}[1] . "[firmware: %s]",
                                short_msg => sprintf(${$operational_status{$result->{$oid_swOperStatus}}}[0], 
                                                     $result->{$oid_swOperStatus}));

    $self->{output}->output_add(severity => 'OK', 
                                short_msg => "All sensors are ok.");
    
    my $oid_swSensorEntry = '.1.3.6.1.4.1.1588.2.1.1.1.1.22.1';
    my $oid_swSensorIndex = '.1.3.6.1.4.1.1588.2.1.1.1.1.22.1.1';
    my $oid_swSensorType = '.1.3.6.1.4.1.1588.2.1.1.1.1.22.1.2';
    my $oid_swSensorStatus = '.1.3.6.1.4.1.1588.2.1.1.1.1.22.1.3';
    my $oid_swSensorValue = '.1.3.6.1.4.1.1588.2.1.1.1.1.22.1.4';
    my $oid_swSensorInfo = '.1.3.6.1.4.1.1588.2.1.1.1.1.22.1.5';
    $result = $self->{snmp}->get_table(oid => $oid_DeviceSensorValueEntry);
    
    foreach my $key ($self->{snmp}->oid_lex_sort(keys %$result)) {
        next if ($key !~ /^$oid_swSensorIndex\.(\d+)/);
        my $index = $1;
        my $status = $result->{$oid_swSensorStatus . '.' . $index};
        my $type = $result->{$oid_swSensorType . '.' . $index};
        my $info = centreon::plugins::misc::trim($result->{$oid_swSensorInfo . '.' . $index});
        my $value = $result->{$oid_swSensorValue . '.' . $index};
        
        $self->{output}->output_add(long_msg => sprintf(${$sensor_status{$status}}[0], $sensor_type_map{$type}->{name}, $info));
        if (${$sensor_status{$status}}[1] ne 'OK') {
            $self->{output}->output_add(severity => ${$sensor_status{$status}}[1],
                                        short_msg => sprintf(${$sensor_status{$status}}[0], $sensor_type_map{$type}->{name}, $info));
        }
        
        if ($value > 0 && $sensor_type_map{$type}->{name} ne 'power-supply') {
             $self->{output}->perfdata_add(label => $info, unit => $sensor_type_map{$type}->{unit},
                                           value => $value);
        }
    }
    
    $self->{output}->display();
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Check brocade operational status and hardware sensors (SW.mib).

=over 8

=back

=cut
