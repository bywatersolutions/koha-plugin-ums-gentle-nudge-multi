use utf8;
package Koha::Schema::Result::KohaPluginComBywatersolutionsUmsgentlenudgeConfigDebitType;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("koha_plugin_com_bywatersolutions_umsgentlenudge_config_dt");

__PACKAGE__->add_columns(
  "config_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "debit_type_code",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 64 },
);

__PACKAGE__->set_primary_key("config_id", "debit_type_code");

__PACKAGE__->belongs_to(
  "config",
  "Koha::Schema::Result::KohaPluginComBywatersolutionsUmsgentlenudgeConfig",
  { config_id => "config_id" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->belongs_to(
  "debit_type",
  "Koha::Schema::Result::AccountDebitType",
  { code => "debit_type_code" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);

1;
