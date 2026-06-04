# UMS Gentle Nudge Multi Branch - Development Guide

Comprehensive development documentation for the UMS Gentle Nudge Multi Branch plugin, including setup, testing, and architecture notes.

## Code Quality Standards

### Testing Standards

**Test File Organization:**
- Database-dependent tests for `a_method` in class `Some::Class` go in `t/db_dependent/Some/Class.t`
- Main subtest titled `'a_method() tests'` contains all tests for that method
- Inner subtests have descriptive titles for specific behaviors being tested

**Test File Structure:**
```perl
use Modern::Perl;
use Test::More tests => N;  # N = number of main subtests + use_ok
use Test::Exception;
use Test::MockModule;

use t::lib::TestBuilder;

BEGIN {
    use_ok('Some::Class');
}

# Global variables for entire test file
my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'a_method() tests' => sub {
    plan tests => 3;  # Number of individual tests
    
    $schema->storage->txn_begin;
    
    # Test implementation - all tests for this method
    
    $schema->storage->txn_rollback;
};

# OR if multiple behaviors need testing:

subtest 'a_method() tests' => sub {
    plan tests => 2;  # Number of inner subtests
    
    subtest 'Successful operations' => sub {
        plan tests => 3;  # Number of individual tests
        
        $schema->storage->txn_begin;
        
        # Test implementation
        
        $schema->storage->txn_rollback;
    };
    
    subtest 'Error conditions' => sub {
        plan tests => 2;
        
        $schema->storage->txn_begin;
        
        # Error test implementation
        
        $schema->storage->txn_rollback;
    };
};
```

**Transaction Rules:**
- Main subtest must be wrapped in transaction if only one behavior tested
- Each inner subtest wrapped in transaction if multiple behaviors tested
- Never nest transactions

**Global Variables:**
- `$schema`: Database schema object (global to test file)
- `$builder`: TestBuilder instance (global to test file)

**Transaction Management:**
- Always use `$schema->storage->txn_begin` at start of subtest
- Always use `$schema->storage->txn_rollback` at end of subtest

### Mandatory Pre-Commit Workflow

**CRITICAL**: All code must be formatted with Koha's tidy.pl before committing.

#### Required Steps Before Every Commit:

1. **Format code with Koha tidy.pl**:
   ```bash
   ktd --name ums --shell --run "cd /kohadevbox/plugins/koha-plugin-ums-gentle-nudge-multi && /kohadevbox/koha/misc/devel/tidy.pl [modified_files...]"
   ```

2. **Remove all .bak files**:
   ```bash
   find . -name "*.bak" -delete
   ```

3. **Run tests to ensure formatting didn't break anything**:
   ```bash
   ktd --name innreach --shell --run "cd /kohadevbox/plugins/koha-plugin-ums-gentle-nudge-multi && export PERL5LIB=/kohadevbox/koha:/kohadevbox/plugins/koha-plugin-ums-gentle-nudge-multi:. && prove -lr t/"
   ```

4. **Commit with clean, formatted code**:
   ```bash
   git add .
   git commit -m "Your commit message"
   ```

#### Standard Commit Sequence:

```bash
# 1. Make your code changes
# ... edit files ...

# 2. Format with Koha tidy.pl
ktd --name ums --shell --run "cd /kohadevbox/plugins/koha-plugin-ums-gentle-nudge-multi && /kohadevbox/koha/misc/devel/tidy.pl Koha/Plugin/Com/ByWaterSolutions/UMSGentleNudge.pm"

# 3. Clean up backup files
find . -name "*.bak" -delete

# 4. Verify tests still pass
ktd --name ums --shell --run "cd /kohadevbox/plugins/koha-plugin-ums-gentle-nudge-multi && export PERL5LIB=/kohadevbox/koha:/kohadevbox/plugins/koha-plugin-ums-gentle-nudge-multi:. && prove -lr t/"

# 5. Commit
git add .
git commit -m "[#XX] Your descriptive commit message"
```

#### Benefits of This Workflow:

- ✅ **Consistent formatting**: All code follows Koha standards
- ✅ **Clean commits**: No backup file pollution in git history
- ✅ **Professional quality**: Matches Koha project standards
- ✅ **Maintainable codebase**: Uniform style across all files
- ✅ **Easy reviews**: Reviewers focus on logic, not formatting

#### Configuration:

The repository includes `.perltidyrc` copied from Koha's main repository to ensure consistent formatting standards.

## Known Issues and Workarounds

None at this time


## Quick Start

### KTD Setup
```bash
# Required environment variables
export KTD_HOME=/path/to/koha-testing-docker
export PLUGINS_DIR=/path/to/plugins/parent/dir
export SYNC_REPO=/path/to/kohaclone

# Launch KTD with plugins
ktd --name ums --plugins up -d
ktd --name ums --wait-ready 120

# Install plugin
ktd --name ums --shell --run "cd /kohadevbox/koha && perl misc/devel/install_plugins.pl"
```

## Standard Testing

### Unit and Integration Tests

The plugin includes comprehensive test coverage across multiple areas:

#### Test Suite Overview

**Unit Tests (t/):**
- **`t/00-load.t`** - Basic module loading tests
- **`t/UMS.t`** - Main plugin functionality tests
- **`t/BackgroundJobWorker.t`** - Background job processing tests
- **`t/lib_Mocks_UMS.t`** - t::lib::Mocks::UMS mock module tests

**Database-Dependent Tests (t/db_dependent/):**
- **`t/db_dependent/configs.t`** - Comprehensive db_dependent method tests

#### Running Tests

```bash
# Get into KTD shell
ktd --name ums --shell

# Inside KTD, set up environment and run tests
cd /kohadevbox/plugins/koha-plugin-ums-gentle-nudge-multi
export PERL5LIB=$PERL5LIB:/kohadevbox/plugins/koha-plugin-ums-gentle-nudge-multi:.

# Run all tests
prove -v t/ t/db_dependent/

# Run specific test categories
prove -v t/                    # Unit tests only
prove -v t/db_dependent/       # Database-dependent tests only

# Run individual tests
prove -v t/UMS.t
prove -v t/db_dependent/configs.t
```

#### Test Coverage Areas


**Database Operations:**
- Plugin configuration storage and retrieval
- Plugin configuration adding, editing, deleting


## Key Architecture Points


### Testing Patterns
- **Database-dependent tests**: Use transaction isolation (`txn_begin`/`txn_rollback`)
- **Test counting**: Each `subtest` = 1 test (not internal test count)
- **Naming**: Class-based (`UMS.t` for main class) or feature-based (`configs.t`)
- **Structure**: Method-based subtests (`add_config() tests`)
- **Mocking**: Use `Test::MockModule` for plugin configuration and external dependencies

## Common Issues & Solutions

### KTD Environment
- **`/.env: No such file or directory`**: Set `KTD_HOME` environment variable
- **Plugin not found**: Check `PLUGINS_DIR` points to parent directory
- **Module loading**: Ensure `PERL5LIB` includes plugin directory

### Testing
- **Test plan errors**: Count subtests, not internal tests
- **Database isolation**: Always use transactions in db_dependent tests
- **Mock warnings**: Use `Test::MockModule` and mock all called methods
- **Configuration mocking**: Mock the `configuration()` method to return test data

### CI/CD
- **GitHub Actions**: No `--proxy` flag needed, separate `up -d` and `--wait-ready`
- **Environment setup**: Use `$GITHUB_PATH` not sudo for PATH modification

## File Structure

```
Koha/Plugin/Com/ByWaterSolutions/
├── UMSGentleNudge.pm                     # Main plugin class
├── /UMSGentleNudge/
   └── ConfigController.pm                #Controller for API
   └── lib
      └── api                             #API structure
      └── Koha
        └── UMSConfig.pm                  # Koha Object
        └── UMSConfigs.pm                 # Koha Objects
        └── Schema/Result/ KohaPluginComBywatersolutionsumsgentlenudgeConfig.pm
   └── templates/                         # Plugin templates


t/
├── 00-load.t                 # Module loading tests
├── UMS.t                     # Main plugin tests
├── CronJob.t     # Cron job tests
```

## Development Workflow

```bash
# Get into KTD shell
ktd --name ums --shell

# Inside KTD:
cd /kohadevbox/koha && perl misc/devel/install_plugins.pl  # Reinstall plugin
cd /kohadevbox/plugins/koha-plugin-ums-gentle-nudge                        # Go to plugin dir
export PERL5LIB=$PERL5LIB:/kohadevbox/plugins/koha-plugin-ums-gentle-nudge :.
prove -v t/ t/db_dependent/                                # Run tests
```


## Packaging Notes

- **Packaging**: Handled by gulpfile (only copies `Koha/` directory)
- **Releases**: Only triggered by version tags (`v*.*.*`)
- **CI**: Tests run on every push, packaging only on tags