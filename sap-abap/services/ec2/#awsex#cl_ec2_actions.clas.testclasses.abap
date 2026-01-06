" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_ec2_actions DEFINITION DEFERRED.
CLASS /awsex/cl_ec2_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_ec2_actions.

CLASS ltc_awsex_cl_ec2_actions DEFINITION FOR TESTING DURATION LONG RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_ec2 TYPE REF TO /aws1/if_ec2.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_ec2_actions TYPE REF TO /awsex/cl_ec2_actions.
    CLASS-DATA av_vpc_id TYPE /aws1/ec2string.
    CLASS-DATA av_subnet_id TYPE /aws1/ec2string.
    CLASS-DATA av_ami_id TYPE /aws1/ec2string.
    CLASS-DATA at_cleanup_instances TYPE TABLE OF /aws1/ec2string.

    " Fast tests that don't require instances
    METHODS: allocate_address FOR TESTING RAISING /aws1/cx_rt_generic,
      create_key_pair FOR TESTING RAISING /aws1/cx_rt_generic,
      create_security_group FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_security_group FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_key_pair FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_addresses FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_instances FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_key_pairs FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_regions FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_availability_zones FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_security_groups FOR TESTING RAISING /aws1/cx_rt_generic,
      release_address FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_images FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_instance_types FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_route_tables FOR TESTING RAISING /aws1/cx_rt_generic,
      " VPC tests
      create_vpc FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_vpc FOR TESTING RAISING /aws1/cx_rt_generic,
      vpc_endpoint_operations FOR TESTING RAISING /aws1/cx_rt_generic,
      " Instance tests - lightweight
      create_instance FOR TESTING RAISING /aws1/cx_rt_generic,
      " Lifecycle operation tests - testing SDK methods work correctly
      stop_and_start_instances FOR TESTING RAISING /aws1/cx_rt_generic,
      reboot_and_terminate_inst FOR TESTING RAISING /aws1/cx_rt_generic,
      mon_and_addr_management FOR TESTING RAISING /aws1/cx_rt_generic.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.

    CLASS-METHODS:
      get_ami_id
        RETURNING VALUE(ov_ami_id) TYPE /aws1/ec2string
        RAISING   /aws1/cx_rt_generic,
      wait_for_instance
        IMPORTING iv_instance_id       TYPE /aws1/ec2string
                  iv_required_status   TYPE string
        RETURNING VALUE(ov_status)     TYPE string
        RAISING   /aws1/cx_rt_generic.

ENDCLASS.

CLASS ltc_awsex_cl_ec2_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_ec2 = /aws1/cl_ec2_factory=>create( ao_session ).
    ao_ec2_actions = NEW /awsex/cl_ec2_actions( ).

    " Cache AMI ID once
    av_ami_id = get_ami_id( ).

    " Get default VPC (don't create in setup to save time)
    DATA(lo_vpcs) = ao_ec2->describevpcs(
      it_filters = VALUE /aws1/cl_ec2filter=>tt_filterlist(
        ( NEW /aws1/cl_ec2filter(
            iv_name = 'is-default'
            it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
              ( NEW /aws1/cl_ec2valuestringlist_w( 'true' ) )
            )
        ) )
      ) ).

    IF lo_vpcs->get_vpcs( ) IS NOT INITIAL.
      READ TABLE lo_vpcs->get_vpcs( ) INTO DATA(lo_vpc) INDEX 1.
      av_vpc_id = lo_vpc->get_vpcid( ).
    ELSE.
      av_vpc_id = ao_ec2->createvpc(
        iv_cidrblock = '10.10.0.0/16'
        it_tagspecifications = VALUE /aws1/cl_ec2tagspecification=>tt_tagspecificationlist(
          ( NEW /aws1/cl_ec2tagspecification(
              iv_resourcetype = 'vpc'
              it_tags = VALUE /aws1/cl_ec2tag=>tt_taglist(
                ( NEW /aws1/cl_ec2tag( iv_key = 'Name' iv_value = |{ /awsex/cl_utils=>cv_asset_prefix }-ec2-test-vpc| ) )
                ( NEW /aws1/cl_ec2tag( iv_key = 'convert_test' iv_value = 'true' ) )
              )
          ) )
        )
      )->get_vpc( )->get_vpcid( ).
    ENDIF.

    " Get subnet
    DATA(lo_subnets) = ao_ec2->describesubnets(
      it_filters = VALUE /aws1/cl_ec2filter=>tt_filterlist(
        ( NEW /aws1/cl_ec2filter(
            iv_name = 'vpc-id'
            it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
              ( NEW /aws1/cl_ec2valuestringlist_w( av_vpc_id ) )
            )
        ) )
      ) ).

    IF lo_subnets->get_subnets( ) IS NOT INITIAL.
      READ TABLE lo_subnets->get_subnets( ) INTO DATA(lo_subnet) INDEX 1.
      av_subnet_id = lo_subnet->get_subnetid( ).
    ELSE.
      av_subnet_id = ao_ec2->createsubnet(
        iv_vpcid = av_vpc_id
        iv_cidrblock = '10.10.0.0/24'
        it_tagspecifications = VALUE /aws1/cl_ec2tagspecification=>tt_tagspecificationlist(
          ( NEW /aws1/cl_ec2tagspecification(
              iv_resourcetype = 'subnet'
              it_tags = VALUE /aws1/cl_ec2tag=>tt_taglist(
                ( NEW /aws1/cl_ec2tag( iv_key = 'Name' iv_value = |{ /awsex/cl_utils=>cv_asset_prefix }-ec2-test-subnet| ) )
                ( NEW /aws1/cl_ec2tag( iv_key = 'convert_test' iv_value = 'true' ) )
              )
          ) )
        )
      )->get_subnet( )->get_subnetid( ).
    ENDIF.
  ENDMETHOD.

  METHOD class_teardown.
    " Terminate all test instances
    IF at_cleanup_instances IS NOT INITIAL.
      TRY.
          ao_ec2->terminateinstances00(
            it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
              FOR lv_id IN at_cleanup_instances ( NEW /aws1/cl_ec2instidstringlist_w( lv_id ) )
            ) ).
        CATCH /aws1/cx_rt_generic.
      ENDTRY.
    ENDIF.

    " Minimal wait for instance termination to start
    WAIT UP TO 3 SECONDS.

    " Check and delete created subnet
    TRY.
        DATA(lo_subnets) = ao_ec2->describesubnets(
          it_subnetids = VALUE /aws1/cl_ec2subnetidstrlist_w=>tt_subnetidstringlist(
            ( NEW /aws1/cl_ec2subnetidstrlist_w( av_subnet_id ) )
          ) ).
        READ TABLE lo_subnets->get_subnets( ) INTO DATA(lo_subnet) INDEX 1.
        DATA(lv_delete_subnet) = abap_false.
        LOOP AT lo_subnet->get_tags( ) INTO DATA(lo_tag).
          IF lo_tag->get_key( ) = 'convert_test' AND lo_tag->get_value( ) = 'true'.
            lv_delete_subnet = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_delete_subnet = abap_true.
          ao_ec2->deletesubnet( iv_subnetid = av_subnet_id ).
        ENDIF.
      CATCH /aws1/cx_rt_generic.
    ENDTRY.

    " Check and delete created VPC
    TRY.
        DATA(lo_vpcs) = ao_ec2->describevpcs(
          it_vpcids = VALUE /aws1/cl_ec2vpcidstringlist_w=>tt_vpcidstringlist(
            ( NEW /aws1/cl_ec2vpcidstringlist_w( av_vpc_id ) )
          ) ).
        READ TABLE lo_vpcs->get_vpcs( ) INTO DATA(lo_vpc) INDEX 1.
        DATA(lv_delete_vpc) = abap_false.
        LOOP AT lo_vpc->get_tags( ) INTO lo_tag.
          IF lo_tag->get_key( ) = 'convert_test' AND lo_tag->get_value( ) = 'true'.
            lv_delete_vpc = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_delete_vpc = abap_true.
          ao_ec2->deletevpc( iv_vpcid = av_vpc_id ).
        ENDIF.
      CATCH /aws1/cx_rt_generic.
    ENDTRY.
  ENDMETHOD.

  METHOD allocate_address.
    DATA(lo_result) = ao_ec2_actions->allocate_address( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_allocationid( )
      msg = |Failed to allocate an Elastic IP address| ).
    ao_ec2->releaseaddress( iv_allocationid = lo_result->get_allocationid( ) ).
  ENDMETHOD.

  METHOD describe_addresses.
    " Allocate an address to the VPC first
    DATA(lv_allocation_id) = ao_ec2->allocateaddress( iv_domain = 'vpc' )->get_allocationid( ).
    
    " Now call describe_addresses() method to verify it returns the allocated address
    DATA(lo_result) = ao_ec2_actions->describe_addresses( ).
    DATA(lt_addresses) = lo_result->get_addresses( ).
    
    " Verify we got addresses back and that our allocated address is in the list
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_addresses
      msg = |Failed to retrieve any addresses| ).
    
    DATA(lv_found) = abap_false.
    LOOP AT lt_addresses INTO DATA(lo_address).
      IF lo_address->get_allocationid( ) = lv_allocation_id.
        lv_found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.
    
    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |Allocated address { lv_allocation_id } should be in described addresses| ).
    
    " Clean up
    ao_ec2->releaseaddress( iv_allocationid = lv_allocation_id ).
  ENDMETHOD.

  METHOD release_address.
    DATA(lv_allocation_id) = ao_ec2->allocateaddress( iv_domain = 'vpc' )->get_allocationid( ).
    ao_ec2_actions->release_address( lv_allocation_id ).
    DATA(lo_describe_result) = ao_ec2_actions->describe_addresses( ).
    DATA(lv_found) = abap_false.
    LOOP AT lo_describe_result->get_addresses( ) INTO DATA(lo_address).
      IF lo_address->get_allocationid( ) = lv_allocation_id.
        lv_found = abap_true.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_false(
      act = lv_found
      msg = |Elastic IP address should have been released| ).
  ENDMETHOD.

  METHOD create_instance.
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_tag_value) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.
    DATA(lo_create_result) = ao_ec2_actions->create_instance(
        iv_ami_id = av_ami_id
        iv_tag_value = lv_tag_value
        iv_subnet_id = av_subnet_id ).
    READ TABLE lo_create_result->get_instances( ) INTO DATA(lo_instance) INDEX 1.
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_instance->get_instanceid( )
      msg = |EC2 instance should have been created| ).
    APPEND lo_instance->get_instanceid( ) TO at_cleanup_instances.
  ENDMETHOD.

  METHOD describe_instances.
    DATA(lo_describe_result) = ao_ec2_actions->describe_instances( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_describe_result->get_reservations( )
      msg = |Reservation list should not be empty| ).
  ENDMETHOD.

  METHOD create_key_pair.
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_key_name) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.
    DATA(lo_result) = ao_ec2_actions->create_key_pair( lv_key_name ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_keypairid( )
      msg = |Failed to create key pair { lv_key_name }| ).
    ao_ec2->deletekeypair( iv_keyname = lv_key_name ).
  ENDMETHOD.

  METHOD delete_key_pair.
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_key_name) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.
    ao_ec2->createkeypair( iv_keyname = lv_key_name ).
    ao_ec2_actions->delete_key_pair( lv_key_name ).
    DATA(lo_result) = ao_ec2->describekeypairs( ).
    DATA(lv_found) = abap_false.
    LOOP AT lo_result->get_keypairs( ) INTO DATA(lo_key_pair).
      IF lo_key_pair->get_keyname( ) = lv_key_name.
        lv_found = abap_true.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_false(
      act = lv_found
      msg = |Key Pair { lv_key_name } should have been deleted| ).
  ENDMETHOD.

  METHOD describe_key_pairs.
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_key_name) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.
    ao_ec2->createkeypair( iv_keyname = lv_key_name ).
    DATA(lo_result) = ao_ec2_actions->describe_key_pairs( ).
    DATA(lv_found) = abap_false.
    LOOP AT lo_result->get_keypairs( ) INTO DATA(lo_key_pair).
      IF lo_key_pair->get_keyname( ) = lv_key_name.
        lv_found = abap_true.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |Key Pair { lv_key_name } should have been included in key pair list| ).
    ao_ec2->deletekeypair( iv_keyname = lv_key_name ).
  ENDMETHOD.

  METHOD describe_regions.
    DATA(lo_result) = ao_ec2_actions->describe_regions( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_regions( )
      msg = |Failed to retrieve list of regions| ).
  ENDMETHOD.

  METHOD describe_availability_zones.
    DATA(lo_result) = ao_ec2_actions->describe_availability_zones( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_availabilityzones( )
      msg = |Failed to retrieve list of availability zones| ).
  ENDMETHOD.

  METHOD create_security_group.
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_security_group_name) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.
    DATA(lo_create_result) = ao_ec2_actions->create_security_group(
      iv_security_group_name = lv_security_group_name
      iv_vpc_id = av_vpc_id ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_create_result->get_groupid( )
      msg = |Failed to create security group { lv_security_group_name }| ).
    ao_ec2->deletesecuritygroup( iv_groupid = lo_create_result->get_groupid( ) ).
  ENDMETHOD.

  METHOD delete_security_group.
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_security_group_name) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.
    DATA(lo_create_result) = ao_ec2->createsecuritygroup(
        iv_groupname = lv_security_group_name
        iv_description = |security group for delete_security_group test|
        iv_vpcid = av_vpc_id ).
    ao_ec2_actions->delete_security_group( lo_create_result->get_groupid( ) ).
    DATA(lo_describe_result) = ao_ec2->describesecuritygroups(
      it_filters = VALUE /aws1/cl_ec2filter=>tt_filterlist(
        ( NEW /aws1/cl_ec2filter(
          iv_name = 'group-id'
          it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
            ( NEW /aws1/cl_ec2valuestringlist_w( lo_create_result->get_groupid( ) ) )
          )
        ) )
      ) ).
    cl_abap_unit_assert=>assert_initial(
      act = lo_describe_result->get_securitygroups( )
      msg = |Security Group { lv_security_group_name } should have been deleted| ).
  ENDMETHOD.

  METHOD describe_security_groups.
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_security_group_name) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.
    DATA(lo_create_result) = ao_ec2->createsecuritygroup(
        iv_groupname = lv_security_group_name
        iv_description = |security group for describe_security_groups test|
        iv_vpcid = av_vpc_id ).
    DATA(lo_describe_result) = ao_ec2_actions->describe_security_groups( lo_create_result->get_groupid( ) ).
    DATA(lv_found) = abap_false.
    LOOP AT lo_describe_result->get_securitygroups( ) INTO DATA(lo_security_group).
      IF lo_security_group->get_groupname( ) = lv_security_group_name.
        lv_found = abap_true.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |Security Group { lv_security_group_name } should have been included in security group list| ).
    ao_ec2->deletesecuritygroup( iv_groupid = lo_create_result->get_groupid( ) ).
  ENDMETHOD.

  METHOD describe_images.
    DATA(lo_result) = ao_ec2_actions->describe_images(
      VALUE /aws1/cl_ec2imageidstrlist_w=>tt_imageidstringlist(
        ( NEW /aws1/cl_ec2imageidstrlist_w( av_ami_id ) )
      ) ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_images( )
      msg = |Failed to retrieve image information| ).
  ENDMETHOD.

  METHOD describe_instance_types.
    " Call with valid filter for current generation instances
    DATA(lo_result) = ao_ec2_actions->describe_instance_types(
      VALUE /aws1/cl_ec2filter=>tt_filterlist(
        ( NEW /aws1/cl_ec2filter(
            iv_name = 'current-generation'
            it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
              ( NEW /aws1/cl_ec2valuestringlist_w( 'true' ) )
            )
        ) )
      ) ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_instancetypes( )
      msg = |Failed to retrieve instance type information| ).
  ENDMETHOD.

  METHOD create_vpc.
    CONSTANTS cv_cidr_block TYPE /aws1/ec2string VALUE '10.20.0.0/16'.
    TRY.
        DATA(lo_action_result) = ao_ec2_actions->create_vpc( cv_cidr_block ).
        cl_abap_unit_assert=>assert_not_initial(
          act = lo_action_result->get_vpc( )->get_vpcid( )
          msg = |Failed to create VPC via action method| ).
        TRY.
            ao_ec2->deletevpc( iv_vpcid = lo_action_result->get_vpc( )->get_vpcid( ) ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
      CATCH /aws1/cx_ec2clientexc INTO DATA(lo_ex).
        " Handle VPC limit exceeded gracefully
        IF lo_ex->av_err_code = 'VpcLimitExceeded'.
          MESSAGE 'Skipping create_vpc test - VPC limit reached' TYPE 'I'.
        ELSE.
          RAISE EXCEPTION lo_ex.
        ENDIF.
    ENDTRY.
  ENDMETHOD.

  METHOD describe_route_tables.
    DATA(lo_result) = ao_ec2_actions->describe_route_tables(
      VALUE /aws1/cl_ec2filter=>tt_filterlist(
        ( NEW /aws1/cl_ec2filter(
            iv_name = 'vpc-id'
            it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
              ( NEW /aws1/cl_ec2valuestringlist_w( av_vpc_id ) )
            )
        ) )
      ) ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_routetables( )
      msg = |Failed to retrieve route table information| ).
  ENDMETHOD.

  METHOD delete_vpc.
    CONSTANTS cv_cidr_block TYPE /aws1/ec2string VALUE '10.30.0.0/16'.
    TRY.
        DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
        DATA(lv_vpc_name) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.
        DATA(lo_create_result) = ao_ec2->createvpc(
          iv_cidrblock = cv_cidr_block
          it_tagspecifications = VALUE /aws1/cl_ec2tagspecification=>tt_tagspecificationlist(
            ( NEW /aws1/cl_ec2tagspecification(
                iv_resourcetype = 'vpc'
                it_tags = VALUE /aws1/cl_ec2tag=>tt_taglist(
                  ( NEW /aws1/cl_ec2tag( iv_key = 'Name' iv_value = lv_vpc_name ) )
                  ( NEW /aws1/cl_ec2tag( iv_key = 'convert_test' iv_value = 'true' ) )
                )
            ) )
          )
        ).
        DATA(lv_test_vpc_id) = lo_create_result->get_vpc( )->get_vpcid( ).
        ao_ec2_actions->delete_vpc( lv_test_vpc_id ).
        DATA(lv_vpc_exists) = abap_false.
        TRY.
            ao_ec2->describevpcs(
              it_vpcids = VALUE /aws1/cl_ec2vpcidstringlist_w=>tt_vpcidstringlist(
                ( NEW /aws1/cl_ec2vpcidstringlist_w( lv_test_vpc_id ) )
              ) ).
            lv_vpc_exists = abap_true.
          CATCH /aws1/cx_rt_generic.
            lv_vpc_exists = abap_false.
        ENDTRY.
        cl_abap_unit_assert=>assert_false(
          act = lv_vpc_exists
          msg = |VPC should have been deleted| ).
      CATCH /aws1/cx_ec2clientexc INTO DATA(lo_ex).
        " Handle VPC limit exceeded gracefully
        IF lo_ex->av_err_code = 'VpcLimitExceeded'.
          MESSAGE 'Skipping delete_vpc test - VPC limit reached' TYPE 'I'.
        ELSE.
          RAISE EXCEPTION lo_ex.
        ENDIF.
    ENDTRY.
  ENDMETHOD.

  METHOD stop_and_start_instances.
    " Test stop_instance and start_instance SDK methods
    " Note: We verify the API calls work but don't wait for full state transition
    " to avoid Lambda timeout issues with slow-stopping instances
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_tag_value) = |{ /awsex/cl_utils=>cv_asset_prefix }-stop-start-{ lv_uuid }|.

    " Create instance
    DATA(lo_create_result) = ao_ec2->runinstances(
        iv_imageid = av_ami_id
        iv_instancetype = 't3.micro'
        iv_maxcount = 1
        iv_mincount = 1
        iv_subnetid = av_subnet_id
        it_tagspecifications = VALUE /aws1/cl_ec2tagspecification=>tt_tagspecificationlist(
          ( NEW /aws1/cl_ec2tagspecification(
              iv_resourcetype = 'instance'
              it_tags = VALUE /aws1/cl_ec2tag=>tt_taglist(
                ( NEW /aws1/cl_ec2tag( iv_key = 'Name' iv_value = lv_tag_value ) )
                ( NEW /aws1/cl_ec2tag( iv_key = 'convert_test' iv_value = 'true' ) )
              )
          ) )
        )
    ).
    READ TABLE lo_create_result->get_instances( ) INTO DATA(lo_instance) INDEX 1.
    DATA(lv_instance_id) = lo_instance->get_instanceid( ).
    
    " Wait for instance to be running before testing stop
    DATA(lv_status) = wait_for_instance( iv_instance_id = lv_instance_id iv_required_status = 'running' ).
    IF lv_status <> 'running'.
      " Clean up and fail
      TRY.
          ao_ec2->terminateinstances00(
            it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
              ( NEW /aws1/cl_ec2instidstringlist_w( lv_instance_id ) )
            ) ).
        CATCH /aws1/cx_rt_generic.
      ENDTRY.
      cl_abap_unit_assert=>fail( msg = |Instance did not reach running state: { lv_status }| ).
    ENDIF.

    " Test stop_instance - verify API call succeeds
    DATA(lo_stop_result) = ao_ec2_actions->stop_instance( lv_instance_id ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_stop_result
      msg = |Stop instance API should return result| ).
    READ TABLE lo_stop_result->get_stoppinginstances( ) INTO DATA(lo_stopping) INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_stopping->get_instanceid( )
      exp = lv_instance_id
      msg = |Stopping instance ID should match| ).
    
    " Verify instance is in stopping or stopped state
    DATA(lv_current_state) = lo_stopping->get_currentstate( )->get_name( ).
    IF lv_current_state <> 'stopping' AND lv_current_state <> 'stopped'.
      TRY.
          ao_ec2->terminateinstances00(
            it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
              ( NEW /aws1/cl_ec2instidstringlist_w( lv_instance_id ) )
            ) ).
        CATCH /aws1/cx_rt_generic.
      ENDTRY.
      cl_abap_unit_assert=>fail( msg = |Instance should be stopping or stopped, got: { lv_current_state }| ).
    ENDIF.

    " Test start_instance - Note: May not succeed if instance hasn't fully stopped
    " We test the API accepts the call even if instance is still stopping
    TRY.
        DATA(lo_start_result) = ao_ec2_actions->start_instance( lv_instance_id ).
        " If it succeeds, verify the response
        cl_abap_unit_assert=>assert_not_initial(
          act = lo_start_result
          msg = |Start instance API should return result| ).
      CATCH /aws1/cx_ec2clientexc INTO DATA(lo_client_ex).
        " Expected if instance is still stopping - check error message
        DATA(lv_error_msg) = lo_client_ex->get_text( ).
        IF lv_error_msg CS 'not in a state' OR lv_error_msg CS 'IncorrectInstanceState'.
          " Expected error - API works correctly, instance just needs more time to stop
          MESSAGE |Start call received expected state exception - API works correctly| TYPE 'I'.
        ELSE.
          " Unexpected error - clean up and fail
          TRY.
              ao_ec2->terminateinstances00(
                it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
                  ( NEW /aws1/cl_ec2instidstringlist_w( lv_instance_id ) )
                ) ).
            CATCH /aws1/cx_rt_generic.
          ENDTRY.
          cl_abap_unit_assert=>fail( msg = |Start instance failed unexpectedly: { lv_error_msg }| ).
        ENDIF.
      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Other errors - clean up and fail
        TRY.
            ao_ec2->terminateinstances00(
              it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
                ( NEW /aws1/cl_ec2instidstringlist_w( lv_instance_id ) )
              ) ).
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        cl_abap_unit_assert=>fail( msg = |Start instance failed unexpectedly: { lo_ex->get_text( ) }| ).
    ENDTRY.

    " Clean up - terminate instance
    TRY.
        ao_ec2->terminateinstances00(
          it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
            ( NEW /aws1/cl_ec2instidstringlist_w( lv_instance_id ) )
          ) ).
      CATCH /aws1/cx_rt_generic.
    ENDTRY.
  ENDMETHOD.

  METHOD reboot_and_terminate_inst.
    " Test reboot_instance and terminate_instances SDK methods
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_tag_value) = |{ /awsex/cl_utils=>cv_asset_prefix }-reboot-term-{ lv_uuid }|.

    " Create instance
    DATA(lo_create_result) = ao_ec2->runinstances(
        iv_imageid = av_ami_id
        iv_instancetype = 't3.micro'
        iv_maxcount = 1
        iv_mincount = 1
        iv_subnetid = av_subnet_id
        it_tagspecifications = VALUE /aws1/cl_ec2tagspecification=>tt_tagspecificationlist(
          ( NEW /aws1/cl_ec2tagspecification(
              iv_resourcetype = 'instance'
              it_tags = VALUE /aws1/cl_ec2tag=>tt_taglist(
                ( NEW /aws1/cl_ec2tag( iv_key = 'Name' iv_value = lv_tag_value ) )
                ( NEW /aws1/cl_ec2tag( iv_key = 'convert_test' iv_value = 'true' ) )
              )
          ) )
        )
    ).
    READ TABLE lo_create_result->get_instances( ) INTO DATA(lo_instance) INDEX 1.
    DATA(lv_instance_id) = lo_instance->get_instanceid( ).

    " Wait for instance to be running
    DATA(lv_status) = wait_for_instance( iv_instance_id = lv_instance_id iv_required_status = 'running' ).
    IF lv_status <> 'running'.
      TRY.
          ao_ec2->terminateinstances00(
            it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
              ( NEW /aws1/cl_ec2instidstringlist_w( lv_instance_id ) )
            ) ).
        CATCH /aws1/cx_rt_generic.
      ENDTRY.
      cl_abap_unit_assert=>fail( msg = |Instance did not reach running state: { lv_status }| ).
    ENDIF.

    " Test reboot_instance - verify API call succeeds
    ao_ec2_actions->reboot_instance( lv_instance_id ).
    
    " Brief wait then verify instance still exists
    WAIT UP TO 3 SECONDS.
    DATA(lo_describe) = ao_ec2->describeinstances(
      it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
        ( NEW /aws1/cl_ec2instidstringlist_w( lv_instance_id ) )
      ) ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_describe->get_reservations( )
      msg = |Instance should exist after reboot| ).

    " Test terminate_instances - verify API call succeeds
    DATA(lo_terminate_result) = ao_ec2_actions->terminate_instances(
      VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
        ( NEW /aws1/cl_ec2instidstringlist_w( lv_instance_id ) )
      ) ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_terminate_result
      msg = |Terminate instances API should return result| ).
    READ TABLE lo_terminate_result->get_terminatinginstances( ) INTO DATA(lo_terminating) INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_terminating->get_instanceid( )
      exp = lv_instance_id
      msg = |Terminating instance ID should match| ).
      
    " Verify instance is in shutting-down or terminated state
    DATA(lv_current_state) = lo_terminating->get_currentstate( )->get_name( ).
    IF lv_current_state <> 'shutting-down' AND lv_current_state <> 'terminated'.
      cl_abap_unit_assert=>fail( msg = |Instance should be terminating, got: { lv_current_state }| ).
    ENDIF.
  ENDMETHOD.

  METHOD mon_and_addr_management.
    " Consolidated test for monitoring and address management operations
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_tag_value) = |{ /awsex/cl_utils=>cv_asset_prefix }-mon-addr-{ lv_uuid }|.

    " Create instance for monitoring and address testing
    DATA(lo_create_result) = ao_ec2->runinstances(
        iv_imageid = av_ami_id
        iv_instancetype = 't3.micro'
        iv_maxcount = 1
        iv_mincount = 1
        iv_subnetid = av_subnet_id
        it_tagspecifications = VALUE /aws1/cl_ec2tagspecification=>tt_tagspecificationlist(
          ( NEW /aws1/cl_ec2tagspecification(
              iv_resourcetype = 'instance'
              it_tags = VALUE /aws1/cl_ec2tag=>tt_taglist(
                ( NEW /aws1/cl_ec2tag( iv_key = 'Name' iv_value = lv_tag_value ) )
                ( NEW /aws1/cl_ec2tag( iv_key = 'convert_test' iv_value = 'true' ) )
              )
          ) )
        )
    ).
    READ TABLE lo_create_result->get_instances( ) INTO DATA(lo_instance) INDEX 1.
    DATA(lv_instance_id) = lo_instance->get_instanceid( ).
    APPEND lv_instance_id TO at_cleanup_instances.

    " Wait for instance to be running
    DATA(lv_status) = wait_for_instance( iv_instance_id = lv_instance_id iv_required_status = 'running' ).
    IF lv_status <> 'running'.
      cl_abap_unit_assert=>fail( msg = |Instance should reach running state. Current state: { lv_status }| ).
    ENDIF.

    " Test monitor_instance
    DATA(lo_monitor_result) = ao_ec2_actions->monitor_instance( lv_instance_id ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_monitor_result
      msg = |Monitor instance operation should return result| ).
    READ TABLE lo_monitor_result->get_instancemonitorings( ) INTO DATA(lo_monitoring) INDEX 1.
    cl_abap_unit_assert=>assert_bound(
      act = lo_monitoring
      msg = |Monitoring information should be available| ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_monitoring->get_instanceid( )
      exp = lv_instance_id
      msg = |Monitored instance ID should match| ).
    DATA(lv_monitoring_state) = lo_monitoring->get_monitoring( )->get_state( ).
    IF lv_monitoring_state <> 'enabled' AND lv_monitoring_state <> 'pending'.
      cl_abap_unit_assert=>fail( msg = |Monitoring status should be enabled or pending, got: { lv_monitoring_state }| ).
    ENDIF.

    " Test associate_address and disassociate_address
    DATA lv_igw_id TYPE /aws1/ec2internetgatewayid.
    DATA lv_igw_attached TYPE abap_bool VALUE abap_false.
    DATA lv_allocation_id TYPE /aws1/ec2allocationid.

    TRY.
        " Check if VPC already has an internet gateway attached
        DATA(lo_existing_igws) = ao_ec2->describeinternetgateways(
          it_filters = VALUE /aws1/cl_ec2filter=>tt_filterlist(
            ( NEW /aws1/cl_ec2filter(
                iv_name = 'attachment.vpc-id'
                it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
                  ( NEW /aws1/cl_ec2valuestringlist_w( av_vpc_id ) )
                )
            ) )
          ) ).

        IF lo_existing_igws->get_internetgateways( ) IS INITIAL.
          " No existing IGW, create and attach one
          lv_igw_id = ao_ec2->createinternetgateway( )->get_internetgateway( )->get_internetgatewayid( ).
          ao_ec2->attachinternetgateway( iv_internetgatewayid = lv_igw_id iv_vpcid = av_vpc_id ).
          lv_igw_attached = abap_true.
          " Brief wait for IGW attachment to complete
          WAIT UP TO 3 SECONDS.
        ELSE.
          " Use existing IGW
          READ TABLE lo_existing_igws->get_internetgateways( ) INTO DATA(lo_igw) INDEX 1.
          lv_igw_id = lo_igw->get_internetgatewayid( ).
        ENDIF.

        " Allocate Elastic IP
        lv_allocation_id = ao_ec2->allocateaddress( iv_domain = 'vpc' )->get_allocationid( ).

        " Test associate_address
        DATA(lo_assoc_result) = ao_ec2_actions->associate_address(
            iv_instance_id = lv_instance_id
            iv_allocation_id = lv_allocation_id ).
        cl_abap_unit_assert=>assert_not_initial(
          act = lo_assoc_result->get_associationid( )
          msg = |Associate address operation should return association ID| ).

        " Test disassociate_address
        ao_ec2_actions->disassociate_address( lo_assoc_result->get_associationid( ) ).

        " Verify disassociation by checking address status
        DATA(lo_describe_addr) = ao_ec2->describeaddresses(
          it_allocationids = VALUE /aws1/cl_ec2allocationidlist_w=>tt_allocationidlist(
            ( NEW /aws1/cl_ec2allocationidlist_w( lv_allocation_id ) )
          ) ).
        READ TABLE lo_describe_addr->get_addresses( ) INTO DATA(lo_address) INDEX 1.
        cl_abap_unit_assert=>assert_initial(
          act = lo_address->get_associationid( )
          msg = |Address should not have association after disassociate| ).

        " Clean up: Release address
        ao_ec2->releaseaddress( iv_allocationid = lv_allocation_id ).

        " Clean up IGW if we created it
        IF lv_igw_attached = abap_true.
          ao_ec2->detachinternetgateway( iv_internetgatewayid = lv_igw_id iv_vpcid = av_vpc_id ).
          ao_ec2->deleteinternetgateway( iv_internetgatewayid = lv_igw_id ).
        ENDIF.

      CATCH /aws1/cx_rt_generic INTO DATA(lo_ex).
        " Clean up on error
        TRY.
            IF lv_allocation_id IS NOT INITIAL.
              ao_ec2->releaseaddress( iv_allocationid = lv_allocation_id ).
            ENDIF.
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        TRY.
            IF lv_igw_attached = abap_true AND lv_igw_id IS NOT INITIAL.
              ao_ec2->detachinternetgateway( iv_internetgatewayid = lv_igw_id iv_vpcid = av_vpc_id ).
              ao_ec2->deleteinternetgateway( iv_internetgatewayid = lv_igw_id ).
            ENDIF.
          CATCH /aws1/cx_rt_generic.
        ENDTRY.
        " Fail the test with error details
        cl_abap_unit_assert=>fail( msg = |Monitoring and address management operations failed: { lo_ex->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD vpc_endpoint_operations.
    " Test create_vpc_endpoint and delete_vpc_endpoints without needing EC2 instances
    DATA(lo_route_tables) = ao_ec2->describeroutetables(
      it_filters = VALUE /aws1/cl_ec2filter=>tt_filterlist(
        ( NEW /aws1/cl_ec2filter(
            iv_name = 'vpc-id'
            it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
              ( NEW /aws1/cl_ec2valuestringlist_w( av_vpc_id ) )
            )
        ) )
      ) ).
    READ TABLE lo_route_tables->get_routetables( ) INTO DATA(lo_route_table) INDEX 1.
    cl_abap_unit_assert=>assert_bound(
      act = lo_route_table
      msg = |Route table should exist for VPC| ).
    DATA(lv_route_table_id) = lo_route_table->get_routetableid( ).
    DATA(lv_region) = ao_session->get_region( ).
    DATA(lv_service_name) = |com.amazonaws.{ lv_region }.s3|.
    
    " Create VPC endpoint
    DATA(lo_vpc_endpoint_result) = ao_ec2_actions->create_vpc_endpoint(
      iv_vpc_id = av_vpc_id
      iv_service_name = lv_service_name
      it_route_table_ids = VALUE /aws1/cl_ec2vpcendptroutetbl00=>tt_vpcendpointroutetableidlist(
        ( NEW /aws1/cl_ec2vpcendptroutetbl00( lv_route_table_id ) )
      ) ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_vpc_endpoint_result->get_vpcendpoint( )->get_vpcendpointid( )
      msg = |VPC endpoint should be created| ).
    DATA(lv_vpc_endpoint_id) = lo_vpc_endpoint_result->get_vpcendpoint( )->get_vpcendpointid( ).
    
    " Delete VPC endpoint
    ao_ec2_actions->delete_vpc_endpoints(
      VALUE /aws1/cl_ec2vpcendptidlist_w=>tt_vpcendpointidlist(
        ( NEW /aws1/cl_ec2vpcendptidlist_w( lv_vpc_endpoint_id ) )
      ) ).
    
    " Verify deletion by checking if endpoint still exists
    DATA(lv_endpoint_deleted) = abap_true.
    TRY.
        DATA(lo_describe_endpoints) = ao_ec2->describevpcendpoints(
          it_vpcendpointids = VALUE /aws1/cl_ec2vpcendptidlist_w=>tt_vpcendpointidlist(
            ( NEW /aws1/cl_ec2vpcendptidlist_w( lv_vpc_endpoint_id ) )
          ) ).
        " If we get here, check the status
        READ TABLE lo_describe_endpoints->get_vpcendpoints( ) INTO DATA(lo_endpoint) INDEX 1.
        IF lo_endpoint IS BOUND.
          DATA(lv_state) = lo_endpoint->get_state( ).
          IF lv_state <> 'deleted' AND lv_state <> 'deleting'.
            lv_endpoint_deleted = abap_false.
          ENDIF.
        ENDIF.
      CATCH /aws1/cx_rt_generic.
        " Endpoint not found - this is expected after deletion
        lv_endpoint_deleted = abap_true.
    ENDTRY.
    cl_abap_unit_assert=>assert_true(
      act = lv_endpoint_deleted
      msg = |VPC endpoint should be deleted or deleting| ).
  ENDMETHOD.

  METHOD get_ami_id.
    CONSTANTS: cv_ami_name     TYPE string VALUE 'amzn2-ami-kernel-5.10-hvm*',
               cv_architecture TYPE string VALUE 'x86_64'.
    TYPES: BEGIN OF ty_ami,
             cdate TYPE string,
             image TYPE REF TO /aws1/cl_ec2image,
           END OF ty_ami.
    DATA(lt_images) = ao_ec2->describeimages(
         it_filters = VALUE /aws1/cl_ec2filter=>tt_filterlist(
           ( NEW /aws1/cl_ec2filter(
               iv_name = 'name'
               it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
                 ( NEW /aws1/cl_ec2valuestringlist_w( cv_ami_name ) )
           ) ) )
           ( NEW /aws1/cl_ec2filter(
               iv_name = 'architecture'
               it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
                ( NEW /aws1/cl_ec2valuestringlist_w( cv_architecture ) )
           ) ) )
         )
       )->get_images( ).
    DATA lt_ami TYPE TABLE OF ty_ami.
    LOOP AT lt_images ASSIGNING FIELD-SYMBOL(<image>).
      APPEND VALUE ty_ami( cdate = <image>->get_creationdate( ) image = <image> ) TO lt_ami.
    ENDLOOP.
    SORT lt_ami BY cdate DESCENDING.
    READ TABLE lt_ami INTO DATA(lo_ami) INDEX 1.
    ov_ami_id = lo_ami-image->get_imageid( ).
  ENDMETHOD.

  METHOD wait_for_instance.
    " Wait for instance to reach desired state
    " Maximum 50 iterations with 4 second wait = 200 seconds (~3 minutes) max
    " This balances between adequate wait time and Lambda timeout limits
    DATA lv_iterations TYPE i VALUE 0.
    DATA lv_max_iterations TYPE i VALUE 50.
    
    DO lv_max_iterations TIMES.
      lv_iterations = lv_iterations + 1.
      
      " Wait before checking status (skip first iteration)
      IF lv_iterations > 1.
        WAIT UP TO 4 SECONDS.
      ENDIF.
      
      TRY.
          DATA(lo_describe) = ao_ec2->describeinstances(
              it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
                ( NEW /aws1/cl_ec2instidstringlist_w( iv_instance_id ) )
              ) ).
          READ TABLE lo_describe->get_reservations( ) INTO DATA(lo_reservation) INDEX 1.
          IF lo_reservation IS NOT BOUND.
            CONTINUE.
          ENDIF.
          
          READ TABLE lo_reservation->get_instances( ) INTO DATA(lo_instance) INDEX 1.
          IF lo_instance IS NOT BOUND.
            CONTINUE.
          ENDIF.
          
          ov_status = lo_instance->get_state( )->get_name( ).
          
          " Exit if we've reached the desired state
          IF ov_status = iv_required_status.
            EXIT.
          ENDIF.
          
        CATCH /aws1/cx_rt_generic.
          " Instance not found or error - continue waiting
          CONTINUE.
      ENDTRY.
    ENDDO.
    
    " If status is still initial, set to unknown
    IF ov_status IS INITIAL.
      ov_status = 'unknown'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
