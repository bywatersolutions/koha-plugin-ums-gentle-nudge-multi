use utf8;
package Koha::Schema::Result::KohaPluginComBywatersolutionsUmsgentlenudgeConfig;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::KohaPluginComBywatersolutionsUmsgentlenudgeConfig

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<koha_plugin_com_bywatersolutions_umsgentlenudge_config>

=cut

__PACKAGE__->table("koha_plugin_com_bywatersolutions_umsgentlenudge_config");

=head1 ACCESSORS

=head2 config_id

  data_type: 'varchar'
  is_nullable: 0
  size: 15

library group id from the library groups table or branchcode from branches

=head2 config_name

  data_type: 'varchar'
  is_nullable: 0
  size: 15

library group id from the library groups table or branchcode from branches

=head2 day_of_week

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Which day of the week

=head2 patron_categories

  data_type: 'varchar'
  is_nullable: 1
  size: 191

Comma delimited list of patron category codes that are eligible for collections. e.g. CAT1,CAT2,CAT3. Leave blank for all categories.

=head2 threshold

  data_type: 'integer'
  default_value: 25
  is_nullable: 0

Minimum amount owed to be sent to collections.

=head2 processing_fee

  data_type: 'integer'
  default_value: 10
  is_nullable: 1

Amount of the processing fee added to the patron account

=head2 collections_flag

  data_type: 'varchar'
  is_nullable: 1
  size: 191

Specify how the patron is flagged as being in collections. If using a patron attribute, it is recommended that the attribute be mapped to the YES_NO category.

=head2 exemptions_flag

  data_type: 'varchar'
  is_nullable: 1
  size: 191

Patrons with the selected attribute will not be flagged.

=head2 fees_newer

  data_type: 'integer'
  default_value: 60
  is_nullable: 0

fees newer than this number of days will be totaled to check if a patron should be sent to collections

=head2 fees_older

  data_type: 'integer'
  default_value: 90
  is_nullable: 0

fewers older than this number of days will be totaled to check if a patron should be sent to collections

=head2 ignore_before

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

fees created before this date will not be part of the total to check if a patron should be sent to collections

=head2 clear_below

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

0, patrons who have paid their fines to below the threshold will not be removed from collections.

=head2 clear_threshold

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

The patron will be cleared from collections if if they do not exceed this threshold.

=head2 restriction

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Newly flagged patrons will have a restriction added to their account.

=head2 remove_minors

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

If 1, patrons under the age of 18 years old will not be included on the collections report.

=head2 unique_email

  data_type: 'varchar'
  is_nullable: 1
  size: 191

If email information is set, plugin will email files to the given addresses.

=head2 additional_email

  data_type: 'varchar'
  is_nullable: 1
  size: 191

If you would like to send to anotehr email address as well

=head2 sftp_host

  data_type: 'varchar'
  is_nullable: 1
  size: 191

=head2 sftp_user

  data_type: 'varchar'
  is_nullable: 1
  size: 191

=head2 sftp_password

  data_type: 'mediumtext'
  is_nullable: 1

=head2 enabled

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

If there is a default configuration, all branches/groups will be included. 0=disabled, 1=enabled

=head2 config_type

  data_type: 'varchar'
  default_value: 'global'
  is_nullable: 0
  size: 15

Options are global (can only have 1 global), branch, or group

=cut

__PACKAGE__->add_columns(
  'config_id',
  { data_type => "varchar", is_nullable => 0, size => 15 },
  'day_of_week',
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  'patron_categories',
  { data_type => "varchar", is_nullable => 1, size => 191 },
  'threshold',
  { data_type => "integer", default_value => 25, is_nullable => 0 },
  'processing_fee',
  { data_type => "integer", default_value => 10, is_nullable => 1 },
  'collections_flag',
  { data_type => "varchar", is_nullable => 1, size => 191 },
  'exemptions_flag',
  { data_type => "varchar", is_nullable => 1, size => 191 },
  'fees_newer',
  { data_type => "integer", default_value => 60, is_nullable => 0 },
  'fees_older',
  { data_type => "integer", default_value => 90, is_nullable => 0 },
  'ignore_before',
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  'clear_below',
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  'clear_threshold',
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  'restriction',
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  'remove_minors',
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  'unique_email',
  { data_type => "varchar", is_nullable => 1, size => 191 },
  'additional_email',
  { data_type => "varchar", is_nullable => 1, size => 191 },
  'sftp_host',
  { data_type => "varchar", is_nullable => 1, size => 191 },
  'sftp_user',
  { data_type => "varchar", is_nullable => 1, size => 191 },
  'sftp_password',
  { data_type => "mediumtext", is_nullable => 1 },
    'enabled' => { is_boolean => 1 },
  'config_type',
  {
    data_type => "varchar",
    default_value => "global",
    is_nullable => 0,
    size => 15,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</config_id>

=back

=cut

__PACKAGE__->set_primary_key("config_id");


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-10-20 19:20:18
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KVYrVuDgyerrx1p/fc4LzQ

sub koha_object_class {
  'Koha::UMSConfig';
}

sub koha_objects_class {
  'Koha::UMSConfigs';
}
# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
