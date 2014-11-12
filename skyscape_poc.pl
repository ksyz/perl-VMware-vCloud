#!/usr/bin/perl -I../lib

=head1 skyscape_poc.pl

This example script uses the API to compose a template to a vApp

=head2 Usage

  ./skyscape_poc.pl --username USER --password PASS --orgname ORG --hostname HOST

Orgname is optional. It will default to "System" if not given.

=head2 Notes

PEC NOTES, Here be dragons.

This script is a PoC used to advance understanding of the SkyScape vCloud API.
Most of it is very specific to the current Infrastructure constraints and setup.
e.g. There are many hardcoded href's throughout the script and even down the library.

There are 2 reasons for this.
a) Fast turnaround at proving the point
b) Rigidity on the VMware::vCloud library that made it difficult not to hardcode things.

The script will build a vApp with a VM based of a template and afterwards it will add another VM to this newly created vApp.

perl -d -Ilib ./skyscape_poc.pl --username "Org Username" --password 'Your password' --orgname ORG_NAME --hostname api.vcd.portal.skyscapecloud.com

=cut

use Data::Dumper;
use Getopt::Long;
use Term::Prompt;
use VMware::vCloud;
use strict;

my ( $username, $password, $hostname, $orgname );

my $ret = GetOptions ( 'username=s' => \$username, 'password=s' => \$password,
                       'orgname=s' => \$orgname, 'hostname=s' => \$hostname );

$hostname = prompt('x','Hostname of the vCloud Server:', '', '' ) unless length $hostname;
$username = prompt('x','Username:', '', undef ) unless length $username;
$password = prompt('p','Password:', '', undef ) and print "\n" unless length $password;
$orgname  = prompt('x','Orgname:', '', 'System' ) unless length $orgname;

my $vcd = new VMware::vCloud ( $hostname, $username, $password, $orgname, { debug => 3 } );

# dfef05b7-a0c8-4aa7-8f24-b8bf0749c375 , base-centos with the broken nat interface.
# base-centos6-x64-80G
my $templateid = 'https://api.vcd.portal.skyscapecloud.com/api/vAppTemplate/vappTemplate-c346f5d7-ea8f-4dae-a09b-a14025115423';
# PSUPP
my $networkid = 'https://api.vcd.portal.skyscapecloud.com/api/network/66ee48e4-4621-4969-bf8e-ef078ef0fa51';
#  MDS - Defra CAPDP-PSUPP (IL2-PROD-BASIC)
my $vdcid = 'https://api.vcd.portal.skyscapecloud.com/api/vdc/c042926f-1ce8-4e4f-87a0-534b8c689b77';
# CAPDP-PSUPP
my $orgid = 'https://api.vcd.portal.skyscapecloud.com/api/org/3aa61e25-d4b0-4101-bace-2a3852509fa6';
# 19-98-3-BASIC-Storage2
my $storage_profile = "https://api.vcd.portal.skyscapecloud.com/api/vdcStorageProfile/fd77b82f-5ff8-479f-b43d-418034bd8183";

# vApp name
my $vapp_name = 'PEC Example vApp03';
my $vapp_href;

### Delete Vapp if it already exists ...
my %vapps = reverse $vcd->list_vapps;
if (exists $vapps{$vapp_name} ) {
    # PEC TODO, fails when vApp is not running ....
    eval {
	my ($task_href,$ret) = $vcd->{api}->vapp_undeploy($vapps{$vapp_name});
	my ($status,$task) = $vcd->wait_on_task($task_href);
    };
    $vcd->delete_vapp($vapps{$vapp_name});
    # PEC NOTES, perhaps we should also handle the task here ?
}




# Build the vApp
my ($task_href,$ret) = $vcd->create_vapp_from_template($vapp_name,$vdcid,$templateid,$networkid);

# Wait on task to complete
my ($status,$task) = $vcd->wait_on_task($task_href);

print "\nSTATUS: $status\n";
print "\n" . Dumper($task) if $status eq 'error';

# vApp href
$vapp_href = $task->{Owner}{$vapp_name}{href};
my $vapp = $vcd->get_vapp( $vapp_href );

my $new_vm_name = "Another VM 1";
($task_href,$ret) = $vcd->{api}->pec_vapp_recompose_add_vm(
    $vapp_name,
    $vapp_href,
    $new_vm_name, # vm_name
    "https://api.vcd.portal.skyscapecloud.com/api/vAppTemplate/vm-2b513e79-da47-4754-b72d-113c802c74d0", # vmHref
    $networkid, # netid
    "https://api.vcd.portal.skyscapecloud.com/api/vdcStorageProfile/79705f5d-5297-4f75-9b62-23df9b9c2829", # Storage Profile
);

($status,$task) = $vcd->wait_on_task($task_href);

$DB::single=1;

print "Before going ...\n";
