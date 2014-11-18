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

my ( $username, $password, $hostname, $orgname, $vapp_name );

my $retopt = GetOptions ( 'username=s' => \$username, 'password=s' => \$password,
                       'orgname=s' => \$orgname, 'hostname=s' => \$hostname,
		       'vappname=s' => \$vapp_name
		   );

$hostname = prompt('x','Hostname of the vCloud Server:', '', '' ) unless length $hostname;
$username = prompt('x','Username:', '', undef ) unless length $username;
$password = prompt('p','Password:', '', undef ) and print "\n" unless length $password;
$orgname  = prompt('x','Orgname:', '', 'System' ) unless length $orgname;

$vapp_name = "default_vapp" unless length $vapp_name;

my $vcd = new VMware::vCloud ( $hostname, $username, $password, $orgname, { debug => 3 } );

# dfef05b7-a0c8-4aa7-8f24-b8bf0749c375 , base-centos with the broken nat interface.
# base-centos6-x64-80G
my $templateid = 'https://api.vcd.portal.skyscapecloud.com/api/vAppTemplate/vappTemplate-c346f5d7-ea8f-4dae-a09b-a14025115423';
# PSUPP
my $networkid = 'https://api.vcd.portal.skyscapecloud.com/api/network/66ee48e4-4621-4969-bf8e-ef078ef0fa51';
my $network_name = "PSUPP";

#  MDS - Defra CAPDP-PSUPP (IL2-PROD-BASIC)
my $vdcid = 'https://api.vcd.portal.skyscapecloud.com/api/vdc/c042926f-1ce8-4e4f-87a0-534b8c689b77';
# CAPDP-PSUPP
my $orgid = 'https://api.vcd.portal.skyscapecloud.com/api/org/3aa61e25-d4b0-4101-bace-2a3852509fa6';
# 19-98-3-BASIC-Storage2
my $storage_profile = "https://api.vcd.portal.skyscapecloud.com/api/vdcStorageProfile/fd77b82f-5ff8-479f-b43d-418034bd8183";

my $vapp_href;

### Delete Vapp if it already exists ...
my %vapps = reverse $vcd->list_vapps;
my ($task_href,$ret);
if (exists $vapps{$vapp_name} ) {
    # PEC TODO, fails when vApp is not running ....
    eval {
	($task_href,$ret) = $vcd->{api}->vapp_undeploy($vapps{$vapp_name});
	my ($status,$task) = $vcd->wait_on_task($task_href);
    };
    my $a = $vcd->delete_vapp($vapps{$vapp_name});
    print "PEC DBG: DELETE\n";
    # PEC NOTES, perhaps we should also handle the task here ?
}

# Build the vApp
# my ($task_href,$ret) = $vcd->create_vapp_from_template($vapp_name,$vdcid,$templateid,$networkid);
# base-centos6-x64-80G
my $box_template = "https://api.vcd.portal.skyscapecloud.com/api/vAppTemplate/vm-33cd95a2-c984-41e1-be2a-750b6597732a";

my %hosts = (
    "vm0" => {
	role => "master",
    },
    "vm1" => {
    	role => "web",
    },
    "vm2" => {
    	role => "app",
    },
    "vm3" => {
    	role => "db",
    }
);

# Lifted from create_vapp_from_template
my %template = $vcd->get_template($box_template);
my %vdc = $vcd->get_vdc($vdcid);

my @links = @{$vdc{Link}};
my $url;

for my $ref (@links) {
    $url = $ref->{href} if $ref->{type} eq 'application/vnd.vmware.vcloud.composeVAppParams+xml';
}


($task_href,$ret) = $vcd->{api}->pec_vapp_create_from_sources(
    {
	vapp_name    => $vapp_name,
	vapp_url     => $template{href},
	vdcid        => $vdcid,
	box_template => $templateid,
	network_name => $network_name,
	hosts        => \%hosts,
	url          => $url,
    });

# Wait on task to complete
my ($status,$task) = $vcd->wait_on_task($task_href);

print "\nSTATUS: $status\n";
print "\n" . Dumper($task) if $status eq 'error';


print "Before going ...\n";
