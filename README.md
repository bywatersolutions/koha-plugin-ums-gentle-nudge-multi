# Unique Collections plugin for Koha

[![CI](https://github.com/bywatersolutions/koha-plugin-ums-gentle-nudge-multi/actions/workflows/main.yaml/badge.svg)](https://github.com/bywatersolutions/koha-plugin-ums-gentle-nudge-multi/actions/workflows/main.yaml)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/bywatersolutions/koha-plugin-ums-gentle-nudge-multi)](https://github.com/bywatersolutions/koha-plugin-ums-gentle-nudge-multi/releases)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

This plugin automates the process of sending patrons to the UMS collections service and updating those patrons in Koha.

## What is ByWater Solutions’ UMS Gentle Nudge plugin?

Gentle Nudge is a product offered by Unique Management Services to assist libraries with the recovery of overdue material and unpaid fines.  ByWater’s Gentle Nudge plugin will generate and send reports of patrons to UMS.  UMS then contacts those patrons and ‘nudges’ them to return to the library to pay their fines and/or return materials.  UMS does not ‘collect’ on behalf of the library.

This plugin allows for configuration on a per library or per library group basis. The most specific (branch) configuration will be used if it exists, if it doesn't exist, group will be used, and default if there's not a branch or group configuration.

### Reports sent to UMS:

1. New submission report: A weekly report of ‘new’ patrons that qualify for collections based on the specified criteria of minimum balance, patron types, account age, etc.
2. Update report: A report sent daily that monitors previously referred/active accounts for changes in account balance. This report keeps UMS current on patron balances for active collection accounts.
3. Synchronization report: This is the same as the Update report above and can be generated manually at any time by clicking the ‘Sync’ button on the plugin configuration page. This report sends the patron ID, patron name and total amount owed. Unique uses this report to query against our database to look for balance discrepancies and is useful for troubleshooting or catching up missed update or submission files.

The plugin will automatically flag patrons who meet specific requirements as being in collections and optionally add a processing fee and restrict their account. Once a patron clears their account by paying their fines to 0, the plugin can optionally automatically clear the collections flag.  At this time, the patron’s account restriction must be manually removed by library staff.

## How to set up the plugin:

### Downloading

From the [release page](https://github.com/bywatersolutions/koha-plugin-ums-gentle-nudge-multi/releases) you can download the latest release in `kpz` format.

### Installation

Install the plugin onto your system.

#### Cronjob
This plugin uses Koha's nightly plugin cronjob system. You can set some environment variables to affect the behavior of this plugin:
* `UMS_COLLECTIONS_DEBUG` - Set to 1 to enable debugging messages
* `UMS_COLLECTIONS_NO_EMAIL` - Set to 1 to test without sending email
* `UMS_COLLECTIONS_ARCHIVES_DIR` - Set to a path to keep copies of the files sent to UMS

## Settings

### Plugin settings

These settings cannot be set per configuration and are instead set for all systems.
A sync button to send a sync for all enabled configurations is included on the page.

#### Global Enabled

Must be enabled for any reports to run. 

Default: Disabled

#### Fines should use the branch of

Which branch should be used to determine the fines.
* `Patron home branch` - The query will select for collections where the patron's home library matches the library/library group
* `Item home branch` - The query will select for collections where the item's home library matches the library/library group
* `Accountline branch of the fine` - The query will select for collections where the branch in the accountline matches the library/library group


### Configuration settings

#### Configuration for

The default is for global and you can add configuration for libraries and library groups.

#### Enabled

Is the configuration enabled or disabled? If there's a group or global enabled that would include the library or group, you can disable for only that library/group by selecting disabled.

Default: Disabled

#### Day of week to send

Choose a single day of the week to report new patrons in collections to Unique. Any day of the week can be selected.

Default: Sunday

#### Patron categories

Select the Koha category codes for the patrons that can be sent to collections. You can select as many category codes as you need. If this field is left blank, all patron categories will be included.

Default: none selected (all will be included in report)

#### Debit types

Select the Koha debit types for the fines that can be sent to collections. You can select as many debit types as you need. If this field is left blank, all debit types will be included. 

If you select "Lost" this means only "Lost" fees would count towards the threshold/be included in the report.

Default: none selected (all will be included in report)

#### Threshold

This is the minimum amount owed by a single patron that will move them to collections.

Default: $10

#### Processing fee

If you charge the patron an additional fee when they are moved to collections, enter it here.  It will be added to the patron’s account as a line item.

Default: $0

#### Require lost fee

Only include the patron if at least one of the outstanding fines is a "Lost" fee.

Default: No

#### Processing fee debit type

Select the debit type to be used when adding a processing fee. 

Default: Manual fee

#### Collections flag

This is the field that Koha will use to mark patrons as being in collections. Sort1, Sort2, or a Patron Attribute are often used. Your Data Librarian and Educator will discuss the options with you.

Default: Sort 1

#### Exemptions flag

This is the field that Koha will use to exclude patrons from being added to collections. Sort1, Sort2, or a Patron Attribute are often used. Your Data Librarian and Educator will discuss the options with you.

Default: Sort 2

#### Count fees newer/older than

These parameters establish the age of fees that Koha will review in determining collection status for new submissions and updates, i.e. the total fees between X and Y days old to check if a patron should be sent to collections. 

Default values are older than 60, newer than 90.

#### Ignore fees created before this date

Fees created before this date will nopt be part of the total used to check if a patron should be sent to collections.

Default: empty

#### Clear flag when balance at or below threshold

If you would like the collections flag automatically cleared for patrons who have paid their balance to the threshold.

Default: No
Threshold default: $0

#### Add/Remove Restriction

If your library restricts patrons while they are in collections. 

Default: No/No

#### Remove minor from collections report
If your library would prefer to exclude minors under the age of 18 from being sent to collections. Remember that this is dependent on having a birthdate available for the patron.

Default: No

#### Unique email

This email will be provided to you by Unique Management Systems. It is the email address at which they will receive the weekly, daily, and sync reports from Koha.

#### Additional email

This email can be an additional send, for example to a staff member to know the report has been sent.

#### SFTP server 

This section will only show if you have SFTP servers configured.

Select the SFTP server to send files to.

#### SMTP server

This secion will only show if you have SMTP servers configured other than the default.

Select the SMTP server to send emails from.

## FAQ

### What if I set a library configuration for a library and a group that library belongs to?

The library configuration will be honored and that library will be excluded from the group report. 
The same goes for groups when the global configuration is enabled.
