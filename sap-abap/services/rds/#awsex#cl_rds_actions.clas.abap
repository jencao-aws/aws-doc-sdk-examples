" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS /awsex/cl_rds_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS descr_db_clust_param_groups
      IMPORTING
        !iv_param_group_name        TYPE /aws1/rdsstring
      RETURNING
        VALUE(oo_result)            TYPE REF TO /aws1/cl_rdsdbclustparamgroup
      RAISING
        /aws1/cx_rt_generic.

    METHODS create_db_clust_param_group
      IMPORTING
        !iv_param_group_name        TYPE /aws1/rdsstring
        !iv_param_group_family      TYPE /aws1/rdsstring
        !iv_description             TYPE /aws1/rdsstring
      RETURNING
        VALUE(oo_result)            TYPE REF TO /aws1/cl_rdsdbclustparamgroup
      RAISING
        /aws1/cx_rt_generic.

    METHODS delete_db_clust_param_group
      IMPORTING
        !iv_param_group_name        TYPE /aws1/rdsstring
      RAISING
        /aws1/cx_rt_generic.

    METHODS descr_db_cluster_parameters
      IMPORTING
        !iv_param_group_name        TYPE /aws1/rdsstring
        !iv_name_prefix             TYPE /aws1/rdsstring OPTIONAL
        !iv_source                  TYPE /aws1/rdsstring OPTIONAL
      RETURNING
        VALUE(ot_parameters)        TYPE /aws1/cl_rdsparameter=>tt_parameterslist
      RAISING
        /aws1/cx_rt_generic.

    METHODS modify_db_clust_param_group
      IMPORTING
        !iv_param_group_name        TYPE /aws1/rdsstring
        !it_update_parameters       TYPE /aws1/cl_rdsparameter=>tt_parameterslist
      RETURNING
        VALUE(oo_result)            TYPE REF TO /aws1/cl_rdsdbclstprmgrnamemsg
      RAISING
        /aws1/cx_rt_generic.

    METHODS describe_db_engine_versions
      IMPORTING
        !iv_engine                  TYPE /aws1/rdsstring
        !iv_param_group_family      TYPE /aws1/rdsstring OPTIONAL
      RETURNING
        VALUE(ot_versions)          TYPE /aws1/cl_rdsdbengineversion=>tt_dbengineversionlist
      RAISING
        /aws1/cx_rt_generic.

    METHODS describe_orderable_db_instance_options
      IMPORTING
        !iv_db_engine               TYPE /aws1/rdsstring
        !iv_db_engine_version       TYPE /aws1/rdsstring
      RETURNING
        VALUE(ot_inst_opts)         TYPE /aws1/cl_rdsorderabledbinsto01=>tt_orderabledbinstoptionslist
      RAISING
        /aws1/cx_rt_generic.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS /AWSEX/CL_RDS_ACTIONS IMPLEMENTATION.


  METHOD describe_db_parameter_groups.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.describe_db_parameter_groups]
    " iv_dbparametergroupname = 'mydbparametergroup'
    TRY.
        oo_result = lo_rds->describedbparametergroups(
          iv_dbparametergroupname = iv_dbparametergroupname ).
        MESSAGE 'DB parameter group retrieved.' TYPE 'I'.
      CATCH /aws1/cx_rdsdbprmgrnotfndfault.
        MESSAGE 'DB parameter group not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[rds.abapv1.describe_db_parameter_groups]
  ENDMETHOD.

  METHOD descr_db_clust_param_groups.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.descr_db_clust_param_groups]
    TRY.
        DATA(lo_output) = lo_rds->describedbclusterparamgroups(
          iv_dbclusterparamgroupname = iv_param_group_name
        ).
        DATA(lt_param_groups) = lo_output->get_dbclusterparametergroups( ).
        IF lines( lt_param_groups ) > 0.
          oo_result = lt_param_groups[ 1 ].
        ENDIF.
      CATCH /aws1/cx_rdsdbprmgrnotfndfault.
    ENDTRY.
    " snippet-end:[rds.abapv1.descr_db_clust_param_groups]
  ENDMETHOD.

  METHOD create_db_parameter_group.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.create_db_parameter_group]
    " iv_dbparametergroupname   = 'mydbparametergroup'
    " iv_dbparametergroupfamily = 'mysql8.0'
    " iv_description            = 'My custom DB parameter group for MySQL 8.0'
    TRY.
        oo_result = lo_rds->createdbparametergroup(
          iv_dbparametergroupname   = iv_dbparametergroupname
          iv_dbparametergroupfamily = iv_dbparametergroupfamily
          iv_description            = iv_description ).
        MESSAGE 'DB parameter group created.' TYPE 'I'.
      CATCH /aws1/cx_rdsdbparmgralrexfault.
        MESSAGE 'DB parameter group already exists.' TYPE 'I'.
      CATCH /aws1/cx_rdsdbprmgrquotaexcd00.
        MESSAGE 'DB parameter group quota exceeded.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[rds.abapv1.create_db_parameter_group]
  ENDMETHOD.


  METHOD create_db_clust_param_group.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.create_db_clust_param_group]
    TRY.
        DATA(lo_output) = lo_rds->createdbclusterparamgroup(
          iv_dbclusterparamgroupname = iv_param_group_name
          iv_dbparametergroupfamily = iv_param_group_family
          iv_description = iv_description
        ).
        oo_result = lo_output->get_dbclusterparametergroup( ).
      CATCH /aws1/cx_rdsdbparmgralrexfault.
        " Re-raise exception - parameter group already exists
        RAISE EXCEPTION TYPE /aws1/cx_rdsdbparmgralrexfault.
      CATCH /aws1/cx_rdsdbprmgrquotaexcd00.
        " Re-raise exception - quota exceeded
        RAISE EXCEPTION TYPE /aws1/cx_rdsdbprmgrquotaexcd00.
    ENDTRY.
    " snippet-end:[rds.abapv1.create_db_clust_param_group]
  ENDMETHOD.

  METHOD delete_db_parameter_group.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.delete_db_parameter_group]
    " iv_dbparametergroupname = 'mydbparametergroup'
    TRY.
        lo_rds->deletedbparametergroup(
          iv_dbparametergroupname = iv_dbparametergroupname ).
        MESSAGE 'DB parameter group deleted.' TYPE 'I'.
      CATCH /aws1/cx_rdsdbprmgrnotfndfault.
        MESSAGE 'DB parameter group not found.' TYPE 'I'.
      CATCH /aws1/cx_rdsinvdbprmgrstatef00.
        MESSAGE 'DB parameter group is in an invalid state.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[rds.abapv1.delete_db_parameter_group]
  ENDMETHOD.


  METHOD delete_db_clust_param_group.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.delete_db_clust_param_group]
    TRY.
        lo_rds->deletedbclusterparamgroup(
          iv_dbclusterparamgroupname = iv_param_group_name
        ).
      CATCH /aws1/cx_rdsdbprmgrnotfndfault.
        " Re-raise exception - parameter group not found
        RAISE EXCEPTION TYPE /aws1/cx_rdsdbprmgrnotfndfault.
      CATCH /aws1/cx_rdsinvdbprmgrstatef00.
        " Re-raise exception - invalid state
        RAISE EXCEPTION TYPE /aws1/cx_rdsinvdbprmgrstatef00.
    ENDTRY.
    " snippet-end:[rds.abapv1.delete_db_clust_param_group]
  ENDMETHOD.

  METHOD describe_db_parameters.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.describe_db_parameters]
    " iv_dbparametergroupname = 'mydbparametergroup'
    " iv_source               = 'user' (optional - filters by parameter source)
    TRY.
        oo_result = lo_rds->describedbparameters(
          iv_dbparametergroupname = iv_dbparametergroupname
          iv_source               = iv_source ).
        DATA(lv_param_count) = lines( oo_result->get_parameters( ) ).
        MESSAGE |Retrieved { lv_param_count } parameters.| TYPE 'I'.
      CATCH /aws1/cx_rdsdbprmgrnotfndfault.
        MESSAGE 'DB parameter group not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[rds.abapv1.describe_db_parameters]
  ENDMETHOD.

  METHOD descr_db_cluster_parameters.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.descr_db_cluster_parameters]
    TRY.
        DATA lv_marker TYPE /aws1/rdsstring VALUE ''.
        DATA lt_all_parameters TYPE /aws1/cl_rdsparameter=>tt_parameterslist.

        DO.
          DATA(lo_output) = lo_rds->describedbclusterparameters(
            iv_dbclusterparamgroupname = iv_param_group_name
            iv_source = iv_source
            iv_marker = lv_marker
          ).

          LOOP AT lo_output->get_parameters( ) INTO DATA(lo_param).
            IF iv_name_prefix IS INITIAL OR
               lo_param->get_parametername( ) CP |{ iv_name_prefix }*|.
              APPEND lo_param TO lt_all_parameters.
            ENDIF.
          ENDLOOP.

          lv_marker = lo_output->get_marker( ).
          IF lv_marker IS INITIAL.
            EXIT.
          ENDIF.
        ENDDO.

        ot_parameters = lt_all_parameters.
      CATCH /aws1/cx_rdsdbprmgrnotfndfault.
        " Re-raise exception - parameter group not found
        RAISE EXCEPTION TYPE /aws1/cx_rdsdbprmgrnotfndfault.
    ENDTRY.
    " snippet-end:[rds.abapv1.descr_db_cluster_parameters]
  ENDMETHOD.

  METHOD modify_db_parameter_group.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.modify_db_parameter_group]
    " iv_dbparametergroupname = 'mydbparametergroup'
    " it_parameters - table containing parameter objects with:
    "   - parametername = 'max_connections'
    "   - parametervalue = '100'
    "   - applymethod = 'immediate' or 'pending-reboot'
    TRY.
        oo_result = lo_rds->modifydbparametergroup(
          iv_dbparametergroupname = iv_dbparametergroupname
          it_parameters           = it_parameters ).
        MESSAGE 'DB parameter group modified.' TYPE 'I'.
      CATCH /aws1/cx_rdsdbprmgrnotfndfault.
        MESSAGE 'DB parameter group not found.' TYPE 'I'.
      CATCH /aws1/cx_rdsinvdbprmgrstatef00.
        MESSAGE 'DB parameter group is in an invalid state.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[rds.abapv1.modify_db_parameter_group]
  ENDMETHOD.

  METHOD modify_db_clust_param_group.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.modify_db_clust_param_group]
    TRY.
        oo_result = lo_rds->modifydbclusterparamgroup(
          iv_dbclusterparamgroupname = iv_param_group_name
          it_parameters = it_update_parameters
        ).
      CATCH /aws1/cx_rdsdbprmgrnotfndfault.
        " Re-raise exception - parameter group not found
        RAISE EXCEPTION TYPE /aws1/cx_rdsdbprmgrnotfndfault.
      CATCH /aws1/cx_rdsinvdbprmgrstatef00.
        " Re-raise exception - invalid state
        RAISE EXCEPTION TYPE /aws1/cx_rdsinvdbprmgrstatef00.
    ENDTRY.
    " snippet-end:[rds.abapv1.modify_db_clust_param_group]
  ENDMETHOD.

  METHOD create_db_snapshot.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.create_db_snapshot]
    " iv_dbsnapshotidentifier = 'mydbsnapshot-2024-01-15'
    " iv_dbinstanceidentifier = 'mydbinstance'
    TRY.
        oo_result = lo_rds->createdbsnapshot(
          iv_dbsnapshotidentifier = iv_dbsnapshotidentifier
          iv_dbinstanceidentifier = iv_dbinstanceidentifier ).
        MESSAGE 'DB snapshot created.' TYPE 'I'.
      CATCH /aws1/cx_rdsdbinstnotfndfault.
        MESSAGE 'DB instance not found.' TYPE 'I'.
      CATCH /aws1/cx_rdsdbsnapalrdyexfault.
        MESSAGE 'DB snapshot already exists.' TYPE 'I'.
      CATCH /aws1/cx_rdsinvdbinststatefa00.
        MESSAGE 'DB instance is in an invalid state.' TYPE 'I'.
      CATCH /aws1/cx_rdssnapquotaexcdfault.
        MESSAGE 'Snapshot quota exceeded.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[rds.abapv1.create_db_snapshot]
  ENDMETHOD.

  METHOD describe_db_snapshots.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.describe_db_snapshots]
    " iv_dbsnapshotidentifier = 'mydbsnapshot-2024-01-15'
    TRY.
        oo_result = lo_rds->describedbsnapshots(
          iv_dbsnapshotidentifier = iv_dbsnapshotidentifier ).
        MESSAGE 'DB snapshot retrieved.' TYPE 'I'.
      CATCH /aws1/cx_rdsdbsnapnotfndfault.
        MESSAGE 'DB snapshot not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[rds.abapv1.describe_db_snapshots]
  ENDMETHOD.

  METHOD describe_db_engine_versions.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.describe_db_engine_versions]
    TRY.
        " iv_engine = 'aurora-mysql'
        " iv_param_group_family = 'aurora-mysql8.0' (optional)
        DATA(lo_output) = lo_rds->describedbengineversions(
          iv_engine = iv_engine
          iv_dbparametergroupfamily = iv_param_group_family
        ).
        ot_versions = lo_output->get_dbengineversions( ).
      CATCH /aws1/cx_rt_generic.
        " Re-raise exception
        RAISE EXCEPTION TYPE /aws1/cx_rt_generic.
    ENDTRY.
    " snippet-end:[rds.abapv1.describe_db_engine_versions]
  ENDMETHOD.


  METHOD describe_orderable_db_instance_options.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.describe_orderable_db_instance_options]
    TRY.
        " iv_db_engine = 'aurora-mysql'
        " iv_db_engine_version = '8.0.mysql_aurora.3.02.0'
        DATA lv_marker TYPE /aws1/rdsstring VALUE ''.
        DATA lt_all_options TYPE /aws1/cl_rdsorderabledbinsto01=>tt_orderabledbinstoptionslist.

        DO.
          DATA(lo_output) = lo_rds->descrorderabledbinstoptions(
            iv_engine = iv_db_engine
            iv_engineversion = iv_db_engine_version
            iv_marker = lv_marker
          ).

          APPEND LINES OF lo_output->get_orderabledbinstoptions( ) TO lt_all_options.

          lv_marker = lo_output->get_marker( ).
          IF lv_marker IS INITIAL.
            EXIT.
          ENDIF.
        ENDDO.

        ot_inst_opts = lt_all_options.
      CATCH /aws1/cx_rt_generic.
        " Re-raise exception
        RAISE EXCEPTION TYPE /aws1/cx_rt_generic.
    ENDTRY.
    " snippet-end:[rds.abapv1.describe_orderable_db_instance_options]
  ENDMETHOD.

  METHOD describe_db_instances.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.describe_db_instances]
    " iv_dbinstanceidentifier = 'mydbinstance'
    TRY.
        oo_result = lo_rds->describedbinstances(
          iv_dbinstanceidentifier = iv_dbinstanceidentifier ).
        MESSAGE 'DB instance retrieved.' TYPE 'I'.
      CATCH /aws1/cx_rdsdbinstnotfndfault.
        MESSAGE 'DB instance not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[rds.abapv1.describe_db_instances]
  ENDMETHOD.


  METHOD create_db_instance.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.create_db_instance]
    " iv_dbname               = 'mydatabase'
    " iv_dbinstanceidentifier = 'mydbinstance'
    " iv_dbparametergroupname = 'mydbparametergroup'
    " iv_engine               = 'mysql'
    " iv_engineversion        = '8.0.35'
    " iv_dbinstanceclass      = 'db.t3.micro'
    " iv_storagetype          = 'gp2'
    " iv_allocatedstorage     = 20
    " iv_masterusername       = 'admin'
    " iv_masteruserpassword   = 'MySecurePassword123!'
    TRY.
        oo_result = lo_rds->createdbinstance(
          iv_dbname               = iv_dbname
          iv_dbinstanceidentifier = iv_dbinstanceidentifier
          iv_dbparametergroupname = iv_dbparametergroupname
          iv_engine               = iv_engine
          iv_engineversion        = iv_engineversion
          iv_dbinstanceclass      = iv_dbinstanceclass
          iv_storagetype          = iv_storagetype
          iv_allocatedstorage     = iv_allocatedstorage
          iv_masterusername       = iv_masterusername
          iv_masteruserpassword   = iv_masteruserpassword ).
        MESSAGE 'DB instance created.' TYPE 'I'.
      CATCH /aws1/cx_rdsdbinstalrdyexfault.
        MESSAGE 'DB instance already exists.' TYPE 'I'.
      CATCH /aws1/cx_rdsinstquotaexcdfault.
        MESSAGE 'DB instance quota exceeded.' TYPE 'I'.
      CATCH /aws1/cx_rdsdbprmgrnotfndfault.
        MESSAGE 'DB parameter group not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[rds.abapv1.create_db_instance]
  ENDMETHOD.


  METHOD delete_db_instance.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_rds) = /aws1/cl_rds_factory=>create( lo_session ).

    " snippet-start:[rds.abapv1.delete_db_instance]
    " iv_dbinstanceidentifier = 'mydbinstance'
    TRY.
        oo_result = lo_rds->deletedbinstance(
          iv_dbinstanceidentifier = iv_dbinstanceidentifier
          iv_skipfinalsnapshot    = abap_true
          iv_deleteautomatedbackups = abap_true ).
        MESSAGE 'DB instance deleted.' TYPE 'I'.
      CATCH /aws1/cx_rdsdbinstnotfndfault.
        MESSAGE 'DB instance not found.' TYPE 'I'.
      CATCH /aws1/cx_rdsinvdbinststatefa00.
        MESSAGE 'DB instance is in an invalid state.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[rds.abapv1.delete_db_instance]
  ENDMETHOD.
ENDCLASS.
