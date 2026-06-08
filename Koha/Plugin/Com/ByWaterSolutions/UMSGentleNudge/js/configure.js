        var UMSDeleteModel = document.getElementById('UMSDeleteModel');
        var UMSConfigModel = document.getElementById('UMSConfigModel');


            UMSConfigModel.addEventListener('show.bs.modal', function (event){
                console.log('modellistener');
                //Button that triggered the modal
                var button = event.relatedTarget;
                // Extract info from data-bs-* attributes
                configtype = button.getAttribute('data-bs-type');
                umsmode = button.getAttribute('data-bs-mode');
                ums_id = button.getAttribute('data-config-id');
                //update the modal content
                //These get information from the button that was clicked
                var modalTitle = UMSConfigModel.querySelector('.modal-title');
                var modalTypeInput = UMSConfigModel.querySelector('.modal-type');
                var modalTypeSelector = modalTypeSelector + configtype;
                var modalIDSelect = '.' + configtype + '_option';
                var modalButton =  UMSConfigModel.querySelector('#modal_button');
                console.log('button' + modalButton);
                console.log('id:' + ums_id +' /mode:' + umsmode + '/modaltitle: ' + modalTitle + ' / modalTypeInput: ' + modalTypeInput + ' / modalTypeSelector: '  + modalTypeSelector  + ' / modalIDSelect: ' + modalIDSelect);
                //Sets the title dynamicly: Mode (New/Edit) type(global, group, or library) configuration
                modalTitle.textContent = umsmode + ' ' + configtype + ' configuration';
                var modalSelector = UMSConfigModel.querySelector('.modal-select-type');
                modalSelector.textContent = 'Select a ' + configtype;
                if (configtype == 'global'){
                    modalSelector.textContent = 'Global';
                }
                if (umsmode == "Edit") loadConfigForEdit();
                else setDefaults();

            
        //show the appropriate choices in the library/group dropdown

           // Array.from(document.querySelectorAll("." + configtype +"_option")).forEach(e =>e.removeAttribute("hidden"));
           $("." + configtype +"_option").each(function(){
            $("." + configtype +"_option").removeAttr('hidden');
           }
           );
           UMSConfigModel.addEventListener('hide.bs.modal', function (){
            $("." + configtype +"_option").each(function(){
                $("." + configtype +"_option").attr("hidden", "true");
            }
              );
          });
                      });
            function setDefaults() {
                        document.getElementById("clear_below").value = '1';
                        document.getElementById("clear_threshold").value = '0';
                        document.getElementById("processing_debit").value = 'MANUAL';
                        document.getElementById("run_on_dow").value ='0';
                        document.getElementById("config-enabled").value = '0';
                        document.getElementById("fees_starting_age").value = '90';
                        document.getElementById("fees_ending_age").value = '60';
                        document.getElementById("processing_fee").value = '10';
                        document.getElementById("age_limitation").value = '0';
                        document.getElementById("add_restriction").value = '0';
                        document.getElementById("remove_restriction").value = '0';
                        document.getElementById("fees_threshold").value = '0';
            }

            function loadConfigForEdit() {
                $.ajax({
                    url: '/api/v1/contrib/ums/config/' + event.relatedTarget.getAttribute('data-config-id'),
                    method: 'GET',
                    headers: { 'x-koha-embed': 'debit_types,patron_categories' },
                    success: function(config) {

                        if (config.config_type == "library") {
                            document.getElementById("umsconfig_id_select").value = config.branch;
                        } 
                        if (config.config_type == "branch") {
                            document.getElementById("umsconfig_id_select").value = config.branch;
                        } 
                        if (config.config_type== "group") {
                            document.getElementById("umsconfig_id_select").value = config.config_group;
                        }
                        document.getElementById("cc_email").value = config.additional_email;
                        document.getElementById("clear_below").value = config.clear_below;
                        document.getElementById("clear_threshold").value = config.clear_threshold;
                        document.getElementById("collections_flag").value = config.collections_flag;
                        document.getElementById("processing_debit").value = config.config_debit_type;
                        document.getElementById("run_on_dow").value = config.day_of_week;
                        document.getElementById("config-enabled").value = config.enabled;
                        document.getElementById("exemption_flag").value = config.exemptions_flag;
                        document.getElementById("fees_starting_age").value = config.fees_newer;
                        document.getElementById("fees_ending_age").value = config.fees_older;
                        document.getElementById("fees_created_before_date_filter").value = config.ignore_before;
                        document.getElementById("umsconfig_categories").value = (config.patron_categories || []).map(c => c.categorycode).join(',');
                        document.getElementById("processing_fee").value = config.processing_fee;
                        document.getElementById("age_limitation").value = config.remove_minors;
                        document.getElementById("add_restriction").value = config.restriction;
                        document.getElementById("remove_restriction").value = config.remove_restriction;
                        document.getElementById("fees_threshold").value = config.threshold;
                        document.getElementById("unique_email").value = config.unique_email;
                        document.getElementById("require_lost_fee").value = config.require_lost;
                    }
                });
            }
        $(document).ready(function() {
            //Load All configs on page load
            loadAll();

            //Event handlers

            $('#group-tab').on('click', function() {
                loadGroups();
            });
            $('#library-tab').on('click', function() {
                loadBranches();
            });

            $('#editconfig').on('click', function() {
                let configId = $(this).data('data-config-id');
                openConfigModal();
            });
            // Form submissions
            $('#config_form').on('submit', function(e) {
                e.preventDefault();
                saveConfig();
            });
            //Initialize DataTables
                function loadAll() {
                $('#config_table').kohaTable({
                    "bDestroy": true,
                    "ajax": {
                        url: '/api/v1/contrib/ums/configs',
                        method: 'GET'
                    },
                    "columns": [
                        {data: "config_name",
                        title: "Configuration Name"
                        },
                        {data: "config_type",
                        render: function (data, type, row) {
                            if (data === "global") {
                                return 'Global configuration';}
                            if (data === "library") {
                                return 'Library configuration';}
                            if (data === "branch") {
                                return 'Library configuration';
                            }
                            if (data === "group") {
                                return 'Group configuration';}
                            },
                        title: "Configuration Type"
                        },
                        {data: "threshold",
                        render: function (data, type, row) {
                            if (data) {
                            return '$' + data;
                            } else {
                                return '$0';
                            }
                        },
                        title: "Threshold"},
                        {data: "processing_fee",
                        render: function (data, type, row) {
                            if (data) {
                            return '$' + data;
                            } else {
                                return '$0';
                            }
                        },
                        title: "Processing Fee"},
                        {data: "enabled",
                        render: function (data, type, row) {
                            if (data === 1) {
                                return '<span class="badge bg-success">Enabled</span>';
                            }
                            if (data === 0) {
                                return '<span class="badge bg-secondary">Disabled</span>';
                            }
                        } ,
                        title: "Enabled"
                        },
                        {data: "config_id",
                        render: function (data, type, row, meta) {
                            if (data === 1) 
                                {return '<button type="button" data-bs-tab="libraryTab" data-bs-toggle="modal" data-bs-target="#UMSConfigModel" data-bs-mode="Edit" id ="editconfig" data-bs-type="' +row["config_type"] + '" class="btn btn-xs btn-primary " edit-config" data-config-id="' + data + '"><i class="fa fa-edit"></i> Edit </button>';
                            } else {return '<button data-bs-toggle="modal" data-bs-target="#UMSConfigModel" data-bs-mode="Edit" id ="editconfig" data-bs-type="' +row["config_type"] + '" class="btn btn-xs btn-primary edit-config" data-config-id="' + data + '"><i class="fa fa-edit"></i> Edit </button> <button data-bs-toggle="modal" data-bs-target="#UMSDeleteModel" data-bs-mode="Delete" id="deleteconfig" class= "btn btn-xs btn-primary delete-config" data-delete-id="' + data+ '"><i class="fa fa-trash"></i> Delete </button>';
                            }
                        },

                        title: "Actions"}]
            });
                }

                function loadGroups () {
                $('#group_table').kohaTable({
                    "bDestroy": true,
                    "ajax": {
                        url: '/api/v1/contrib/ums/configs/?config_type=group',
                        method: 'GET'
                    },
                    "columns": [
                        {data: "config_name",
                        title: "Configuration Name"
                        },
                        {data: "config_type",
                        render: function (data, type, row) {
                            if (data === "global") {
                                return 'Global configuration';}
                            if (data === "library") {
                                return 'Library configuration';}
                            if (data === "branch") {
                                return 'Library configuration';}
                            if (data === "group") {
                                return 'Group configuration';}
                            },
                        title: "Configuration Type"
                        },
                        {data: "threshold",
                        render: function (data, type, row) {
                            if (data) {
                            return '$' + data;
                            } else {
                                return 'Not configured';
                            }
                        },
                        title: "Threshold"},
                        {data: "processing_fee",
                        render: function (data, type, row) {
                            if (data) {
                            return '$' + data;
                            } else {
                                return 'Not configured';
                            }
                        },
                        title: "Processing Fee"},
                        {data: "enabled",
                        render: function (data, type, row) {
                            if (data === 1) {
                                return '<span class="badge bg-success">Enabled</span>';
                            }
                            if (data === 0) {
                                return '<span class="badge bg-secondary">Disabled</span>';
                            }
                        } ,
                        title: "Enabled"
                        },
                        {data: "config_id",
                        render: function (data, type, row, meta) {
                            if (data === 1) 
                                {return '<button type="button" data-bs-tab="libraryTab" data-bs-toggle="modal" data-bs-target="#UMSConfigModel" data-bs-mode="Edit" id ="editconfig" data-bs-type="' +row["config_type"] + '" class="btn btn-xs btn-primary " edit-config" data-config-id="' + data + '"><i class="fa fa-edit"></i> Edit </button>';
                            } else {return '<button data-bs-toggle="modal" data-bs-target="#UMSConfigModel" data-bs-mode="Edit" id ="editconfig" data-bs-type="' +row["config_type"] + '" class="btn btn-xs btn-primary edit-config" data-config-id="' + data + '"><i class="fa fa-edit"></i> Edit </button> <button data-bs-toggle="modal" data-bs-target="#UMSDeleteModel" data-bs-mode="Delete" id="deleteconfig" class= "btn btn-xs btn-primary delete-config" data-delete-id="' + data+ '"><i class="fa fa-trash"></i> Delete </button>';
                            }
                        },

                        title: "Actions"}]
            });
                }
                function loadBranches() {
                $('#library_table').kohaTable({
                    "bDestroy": true,
                    "ajax": {
                        url: '/api/v1/contrib/ums/configs/?config_type=library',
                        method: 'GET'
                    },
                    "columns": [
                        {data: "config_name",
                        title: "Configuration Name"
                        },
                        {data: "config_type",
                        render: function (data, type, row) {
                            if (data === "global") {
                                return 'Global configuration';}
                            if (data === "library") {
                                return 'Library configuration';}
                            if (data === "branch") {
                                return 'Library configuration';}
                            if (data === "group") {
                                return 'Group configuration';}
                            },
                        title: "Configuration Type"
                        },
                        {data: "threshold",
                        render: function (data, type, row) {
                            if (data) {
                            return '$' + data;
                            } else {
                                return 'Not configured';
                            }
                        },
                        title: "Threshold"},
                        {data: "processing_fee",
                        render: function (data, type, row) {
                            if (data) {
                            return '$' + data;
                            } else {
                                return 'Not configured';
                            }
                        },
                        title: "Processing Fee"},
                        {data: "enabled",
                        render: function (data, type, row) {
                            if (data === 1) {
                                return '<span class="badge bg-success">Enabled</span>';
                            }
                            if (data === 0) {
                                return '<span class="badge bg-secondary">Disabled</span>';
                            }
                        } ,
                        title: "Enabled"
                        },
                        {data: "config_id",
                        render: function (data, type, row, meta) {
                            if (data === 1) 
                                {return '<button type="button" data-bs-tab="libraryTab" data-bs-toggle="modal" data-bs-target="#UMSConfigModel" data-bs-mode="Edit" id ="editconfig" data-bs-type="' +row["config_type"] + '" class="btn btn-xs btn-primary " edit-config" data-config-id="' + data + '"><i class="fa fa-edit"></i> Edit </button>';
                            } else {return '<button data-bs-toggle="modal" data-bs-target="#UMSConfigModel" data-bs-mode="Edit" id ="editconfig" data-bs-type="' +row["config_type"] + '" class="btn btn-xs btn-primary edit-config" data-config-id="' + data + '"><i class="fa fa-edit"></i> Edit </button> <button data-bs-toggle="modal" data-bs-target="#UMSDeleteModel" data-bs-mode="Delete" id="deleteconfig" class= "btn btn-xs btn-primary delete-config" data-delete-id="' + data+ '"><i class="fa fa-trash"></i> Delete </button>';
                            }
                        },

                        title: "Actions"}]
            });
                }

            function deleteConfig() {
                $.ajax({
                    url: '/api/v1/contrib/ums/config/' + del_ums_id,
                    method: 'delete',
                    });}

            function saveConfig() {
                if( $(configtype = "library")) {
                    umslibrary = $('#umsconfig_id_select').val();
                }
                if ($(configtype = "branch")) {
                    umslibrary = $('#umsconfig_id_select').val();
                }
                if ($(configtype = "group")) {
                    umsgroup = $('#umsconfig_id_select').val();
                }
                if ($(configtype = "global")) {
                }
                var debit_type_select = document.getElementById('processing_debit');
                var debit_type = debit_type_select.value;
                var exemption_select = document.getElementById('processing_debit');
                let configData = {
                    additional_email: $('#cc_email').val(),
                    branch: umslibrary,
                    clear_below: $('#clear_below').val(),
                    clear_threshold: $('#clear_threshold').val(),
                    collections_flag: $('#collections_flag').val(),
                    config_group: umsgroup,
                    config_name: $('#config_name').val(),
                    config_type: configtype,
                    day_of_week: $('#run_on_dow').val(),
                    config_debit_type: debit_type,
                    enabled: $('#config-enabled').val(),
                    exemptions_flag: $('#exemption_flag').val(),
                    fees_newer: $('#fees_starting_age').val(),
                    fees_older: $('#fees_ending_age').val(),
                    ignore_before: $('#fees_created_before_date_filter').val(),
                    patron_category_codes: $('#umsconfig_categories').val() ? $('#umsconfig_categories').val().split(',').filter(Boolean) : [],
                    processing_fee: $('#processing_fee').val(),
                    remove_minors: $('#age_limitation').val(),
                    remove_restriction:$('#remove_restriction').val(),
                    require_lost: $('#require_lost_fee').val(),
                    restriction: $('#add_restriction').val(),
                    threshold: $('#fees_threshold').val(),
                    unique_email: $('#unique_email').val()
                };
                method = '';
                let url = '/api/v1/contrib/ums/configs';
                if (umsmode == "New") {
                 method = 'POST';
                }
                if (umsmode =="Edit"){
                     url = '/api/v1/contrib/ums/config/' + ums_id;
                     method = 'PUT';
                }
                 $.ajax({
                    url: url,
                    method: method,
                    data: JSON.stringify(configData),
                    contentType: 'application/json',
                    success: function(data) {
                    //showMessage(configId ? 'Config updated successfully' : 'Config created successfully', 'success');
                        $('#UMSConfigModel').modal('hide');
                        loadAll();
                    },
                    error: function(xhr, status, error) {
                        let message = 'Failed to save config';
                        if (xhr.responseJSON && xhr.responseJSON.error) {
                            message += ': ' + xhr.responseJSON.error;
                        }
                        //showMessage(message, 'danger');
                    }
                  });
              }

            function openConfigModal() {
                if (ums_id) {
                    //Edit existing configs
                    loadConfigForEdit(ums_id);
                }
            }
            function openDeleteModal() {
            }
        });