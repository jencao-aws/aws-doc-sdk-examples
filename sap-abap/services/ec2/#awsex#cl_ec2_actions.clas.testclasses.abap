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
    CLASS-DATA at_instance_id TYPE TABLE OF /aws1/ec2string. " table of instance IDs to terminate
    CLASS-DATA av_instance_id TYPE /aws1/ec2string. " main instance Id for tests

    METHODS: allocate_address FOR TESTING RAISING /aws1/cx_rt_generic,
      associate_address FOR TESTING RAISING /aws1/cx_rt_generic,
      create_instance FOR TESTING RAISING /aws1/cx_rt_generic,
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
      monitor_instance FOR TESTING RAISING /aws1/cx_rt_generic,
      reboot_instance FOR TESTING RAISING /aws1/cx_rt_generic,
      release_address FOR TESTING RAISING /aws1/cx_rt_generic,
      start_instances FOR TESTING RAISING /aws1/cx_rt_generic,
      stop_instances FOR TESTING RAISING /aws1/cx_rt_generic,
      disassociate_address FOR TESTING RAISING /aws1/cx_rt_generic,
      terminate_instances FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_images FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_instance_types FOR TESTING RAISING /aws1/cx_rt_generic,
      create_vpc FOR TESTING RAISING /aws1/cx_rt_generic,
      describe_route_tables FOR TESTING RAISING /aws1/cx_rt_generic,
      create_vpc_endpoint FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_vpc_endpoints FOR TESTING RAISING /aws1/cx_rt_generic,
      delete_vpc FOR TESTING RAISING /aws1/cx_rt_generic.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic /awsex/cx_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic /awsex/cx_generic.


    CLASS-METHODS:
      get_ami_id
        RETURNING VALUE(ov_ami_id) TYPE /aws1/ec2string
        RAISING   /aws1/cx_rt_generic,
      wait_until_status_change
        IMPORTING iv_required_status       TYPE string
                  iv_instance_id           TYPE string
        RETURNING VALUE(ov_current_status) TYPE string
        RAISING   /aws1/cx_rt_generic,
      run_instance
        IMPORTING iv_subnet_id          TYPE /aws1/ec2subnetid
        RETURNING VALUE(ov_instance_id) TYPE /aws1/ec2string
        RAISING   /aws1/cx_rt_generic,
      terminate_instance
        IMPORTING iv_instance_id TYPE /aws1/ec2string
        RAISING   /aws1/cx_rt_generic.

ENDCLASS.

CLASS ltc_awsex_cl_ec2_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_ec2 = /aws1/cl_ec2_factory=>create( ao_session ).
    ao_ec2_actions = NEW /awsex/cl_ec2_actions( ).

    " Try to get default VPC first
    DATA(lo_vpcs) = ao_ec2->describevpcs(
      it_filters = VALUE /aws1/cl_ec2filter=>tt_filterlist(
        ( NEW /aws1/cl_ec2filter(
            iv_name = 'is-default'
            it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
              ( NEW /aws1/cl_ec2valuestringlist_w( 'true' ) )
            )
        ) )
      ) ).

    " If default VPC exists, use it; otherwise create a new one
    IF lo_vpcs->get_vpcs( ) IS NOT INITIAL.
      READ TABLE lo_vpcs->get_vpcs( ) INTO DATA(lo_vpc) INDEX 1.
      av_vpc_id = lo_vpc->get_vpcid( ).
    ELSE.
      " Create VPC with convert_test tag
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

    " Get or create subnet in the VPC
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
      " Create subnet with convert_test tag
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

    " Create instance with convert_test tag for shared tests
    av_instance_id = run_instance( av_subnet_id ).

  ENDMETHOD.

  METHOD class_teardown.
    " Terminate all test instances
    LOOP AT at_instance_id ASSIGNING FIELD-SYMBOL(<instance_id>).
      terminate_instance( <instance_id> ).
    ENDLOOP.

    " Check if we created the subnet (has convert_test tag)
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

    " Only delete subnet if we created it
    IF lv_delete_subnet = abap_true.
      DO 4 TIMES.
        TRY.
            ao_ec2->deletesubnet( iv_subnetid = av_subnet_id ).
            EXIT.
          CATCH /aws1/cx_ec2clientexc INTO DATA(lo_ex).
            IF lo_ex->get_text( ) CS 'dependencies'.
              WAIT UP TO 15 SECONDS.
            ELSE.
              RAISE EXCEPTION lo_ex.
            ENDIF.
        ENDTRY.
      ENDDO.
    ENDIF.

    " Check if we created the VPC (has convert_test tag)
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

    " Only delete VPC if we created it
    IF lv_delete_vpc = abap_true.
      DO 4 TIMES.
        TRY.
            ao_ec2->deletevpc( iv_vpcid = av_vpc_id ).
            EXIT.
          CATCH /aws1/cx_ec2clientexc INTO lo_ex.
            IF lo_ex->av_err_code = 'DependencyViolation'.
              WAIT UP TO 15 SECONDS.
            ELSEIF lo_ex->av_err_code = 'InvalidVpcID.NotFound'.
              EXIT.
            ELSE.
              RAISE EXCEPTION lo_ex.
            ENDIF.
        ENDTRY.
      ENDDO.
    ENDIF.
  ENDMETHOD.

  METHOD allocate_address.
    DATA(lo_result) = ao_ec2_actions->allocate_address( ).

    cl_abap_unit_assert=>assert_not_initial(
          act = lo_result->get_allocationid( )
          msg = |Failed to allocate an Elastic IP address| ).

    ao_ec2->releaseaddress( iv_allocationid = lo_result->get_allocationid( ) ).

  ENDMETHOD.
  METHOD associate_address.
    DATA(lv_internet_gateway_id) = ao_ec2->createinternetgateway( )->get_internetgateway( )->get_internetgatewayid( ).
    ao_ec2->attachinternetgateway( iv_internetgatewayid = lv_internet_gateway_id
                                   iv_vpcid = av_vpc_id ).
    wait_until_status_change( iv_instance_id = av_instance_id
                              iv_required_status = 'running' ).
    DATA(lv_allocation_id) = ao_ec2->allocateaddress( iv_domain = 'vpc' )->get_allocationid( ).

    DATA(lo_result) = ao_ec2_actions->associate_address(
        iv_instance_id = av_instance_id
        iv_allocation_id = lv_allocation_id ).

    cl_abap_unit_assert=>assert_not_initial(
          act = lo_result->get_associationid( )
          msg = |Failed to associate Elastic IP address with EC2 instancce| ).

    ao_ec2->disassociateaddress( iv_associationid = lo_result->get_associationid( ) ).
    ao_ec2->releaseaddress( iv_allocationid = lv_allocation_id ).
    ao_ec2->detachinternetgateway( iv_internetgatewayid = lv_internet_gateway_id
                                   iv_vpcid = av_vpc_id ).
    ao_ec2->deleteinternetgateway( iv_internetgatewayid = lv_internet_gateway_id ).
  ENDMETHOD.
  METHOD describe_addresses.
    DATA(lv_internet_gateway_id) = ao_ec2->createinternetgateway( )->get_internetgateway( )->get_internetgatewayid( ).
    ao_ec2->attachinternetgateway( iv_internetgatewayid = lv_internet_gateway_id
                                   iv_vpcid = av_vpc_id ).
    wait_until_status_change( iv_instance_id = av_instance_id
                              iv_required_status = 'running' ).

    DATA(lo_allocate_result) = ao_ec2->allocateaddress( iv_domain = 'vpc' ).
    DATA(lo_associate_result) = ao_ec2->associateaddress( iv_allocationid = lo_allocate_result->get_allocationid( )
                                                          iv_instanceid = av_instance_id ).

    DATA(lo_describe_result) = ao_ec2_actions->describe_addresses( ).

    LOOP AT lo_describe_result->get_addresses( ) INTO DATA(lo_address).
      IF lo_address->get_instanceid( ) = av_instance_id AND lo_address->get_publicip( ) = lo_allocate_result->get_publicip( ).
        DATA(lv_found) = abap_true.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |Elastic IP address associated with EC2 instance should have been included in the address list| ).

    ao_ec2->disassociateaddress( iv_associationid = lo_associate_result->get_associationid( ) ).
    ao_ec2->releaseaddress( iv_allocationid = lo_allocate_result->get_allocationid( ) ).
    ao_ec2->detachinternetgateway( iv_internetgatewayid = lv_internet_gateway_id
                                   iv_vpcid = av_vpc_id ).
    ao_ec2->deleteinternetgateway( iv_internetgatewayid = lv_internet_gateway_id ).
  ENDMETHOD.
  METHOD release_address.
    DATA(lv_internet_gateway_id) = ao_ec2->createinternetgateway( )->get_internetgateway( )->get_internetgatewayid( ).
    ao_ec2->attachinternetgateway( iv_internetgatewayid = lv_internet_gateway_id
                                   iv_vpcid = av_vpc_id ).
    wait_until_status_change( iv_instance_id = av_instance_id
                              iv_required_status = 'running' ).

    DATA(lo_allocate_result) = ao_ec2->allocateaddress( iv_domain = 'vpc' ).
    DATA(lo_associate_result) = ao_ec2->associateaddress( iv_allocationid = lo_allocate_result->get_allocationid( )
                                                          iv_instanceid = av_instance_id ).

    ao_ec2->disassociateaddress( iv_associationid = lo_associate_result->get_associationid( ) ).
    ao_ec2_actions->release_address( lo_allocate_result->get_allocationid( ) ).

    DATA(lo_describe_result) = ao_ec2_actions->describe_addresses( ).

    LOOP AT lo_describe_result->get_addresses( ) INTO DATA(lo_address).
      IF lo_address->get_publicip( ) = lo_allocate_result->get_publicip( ).
        DATA(lv_found) = abap_true.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_false(
      act = lv_found
      msg = |Elastic IP address should have been released| ).

    ao_ec2->detachinternetgateway( iv_internetgatewayid = lv_internet_gateway_id
                                   iv_vpcid = av_vpc_id ).
    ao_ec2->deleteinternetgateway( iv_internetgatewayid = lv_internet_gateway_id ).
  ENDMETHOD.
  METHOD create_instance.
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_tag_value) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.

    DATA(lo_create_result) = ao_ec2_actions->create_instance(
        iv_ami_id = get_ami_id( )
        iv_tag_value = lv_tag_value
        iv_subnet_id = av_subnet_id ).
    READ TABLE lo_create_result->get_instances( ) INTO DATA(lo_instance) INDEX 1.
    DATA(lv_current_status) = wait_until_status_change( iv_instance_id = lo_instance->get_instanceid( )
                                                        iv_required_status = 'running' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_current_status
      exp = 'running'
      msg = |EC2 instance { lo_instance->get_instanceid( ) } should have been in 'running' state| ).
    APPEND lo_instance->get_instanceid( ) TO at_instance_id.
  ENDMETHOD.
  METHOD monitor_instance.
    ao_ec2_actions->monitor_instance( av_instance_id ).
    WAIT UP TO 5 SECONDS.
    DATA(lo_describe_result) = ao_ec2->describeinstances(
      it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
       ( NEW /aws1/cl_ec2instidstringlist_w( av_instance_id ) )
      ) ).
    READ TABLE lo_describe_result->get_reservations( ) INTO DATA(lo_reservation) INDEX 1.
    READ TABLE lo_reservation->get_instances( ) INTO DATA(lo_describe_instance) INDEX 1.
    cl_abap_unit_assert=>assert_equals(
          exp = lo_describe_instance->get_monitoring( )->get_state( )
          act = 'enabled'
          msg = |Detailed monitoring should have been enabled| ).
  ENDMETHOD.
  METHOD reboot_instance.
    wait_until_status_change( iv_instance_id = av_instance_id
                              iv_required_status = 'running' ).
    ao_ec2_actions->reboot_instance( av_instance_id ).
    DATA(lv_current_status) = wait_until_status_change( iv_instance_id = av_instance_id
                                                        iv_required_status = 'running' ).

    cl_abap_unit_assert=>assert_equals(
          exp = lv_current_status
          act = 'running'
          msg = |Failed to reboot the specified instance| ).
  ENDMETHOD.
  METHOD start_instances.
    ao_ec2->stopinstances(
      it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
        ( NEW /aws1/cl_ec2instidstringlist_w( av_instance_id ) )
      ) ).
    wait_until_status_change( iv_instance_id = av_instance_id
                              iv_required_status = 'stopped' ).

    DATA(lo_start_result) = ao_ec2_actions->start_instance( av_instance_id ).
    READ TABLE lo_start_result->get_startinginstances( ) INTO DATA(lo_start_instance) INDEX 1.
    cl_abap_unit_assert=>assert_equals(
          exp = lo_start_instance->get_currentstate( )->get_name( )
          act = 'pending'
          msg = |Instance should have been in 'pending' state when a request is made to start a stopped instance| ).

    DATA(lv_current_status) = wait_until_status_change( iv_instance_id = av_instance_id
                                                        iv_required_status = 'running' ).
    cl_abap_unit_assert=>assert_equals(
          exp = lv_current_status
          act = 'running'
          msg = |Failed to start a stopped instance| ).
  ENDMETHOD.
  METHOD stop_instances.
    DATA(lo_start_result) = ao_ec2_actions->start_instance( av_instance_id ).
    wait_until_status_change( iv_instance_id = av_instance_id
                              iv_required_status = 'running' ).
    DATA(lo_stop_result) = ao_ec2_actions->stop_instance( av_instance_id ).
    READ TABLE lo_stop_result->get_stoppinginstances( ) INTO DATA(lo_stop_instance) INDEX 1.
    cl_abap_unit_assert=>assert_equals(
          exp = lo_stop_instance->get_currentstate( )->get_name( )
          act = 'stopping'
          msg = |Instance should have been in 'stopping' state when a request is made to stop a running instance| ).

    DATA(lv_current_status) = wait_until_status_change( iv_instance_id = av_instance_id
                                                        iv_required_status = 'stopped' ).
    cl_abap_unit_assert=>assert_equals(
          exp = lv_current_status
          act = 'stopped'
          msg = |Failed to stop a running instance| ).

  ENDMETHOD.
  METHOD describe_instances.
    DATA(lo_describe_result) = ao_ec2_actions->describe_instances( ).
    READ TABLE lo_describe_result->get_reservations( ) INTO DATA(lo_reservation) INDEX 1.
    cl_abap_unit_assert=>assert_not_initial(
          act = lo_reservation->get_instances( )
          msg = |Instance List should not be empty| ).
  ENDMETHOD.
  METHOD create_key_pair.
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_key_name) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.

    DATA(lo_result) = ao_ec2_actions->create_key_pair( lv_key_name ).
    cl_abap_unit_assert=>assert_not_initial(
          act = lo_result->get_keypairid( )
          msg = |Failed to create key pair { lv_key_name }| ).


    IF lo_result->get_keyfingerprint( ) IS NOT INITIAL AND lo_result->get_keymaterial( ) IS NOT INITIAL AND lo_result->get_keyname( ) = lv_key_name.
      DATA(lv_has_details) = abap_true.
    ENDIF.

    cl_abap_unit_assert=>assert_true(
      act = lv_has_details
      msg = |The response object for key pair { lv_key_name } does not contain the required elements| ).

    ao_ec2->deletekeypair( iv_keyname = lv_key_name ).
  ENDMETHOD.
  METHOD delete_key_pair.
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_key_name) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.

    ao_ec2->createkeypair( iv_keyname = lv_key_name ).
    ao_ec2_actions->delete_key_pair( lv_key_name ).
    DATA(lo_result) = ao_ec2->describekeypairs( ).


    LOOP AT lo_result->get_keypairs( ) INTO DATA(lo_key_pair).
      IF lo_key_pair->get_keyname( ) = lv_key_name.
        DATA(lv_found) = abap_true.
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


    LOOP AT lo_result->get_keypairs( ) INTO DATA(lo_key_pair).
      IF lo_key_pair->get_keyname( ) = lv_key_name.
        DATA(lv_found) = abap_true.
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

    DATA(lo_create_result) = ao_ec2_actions->create_security_group( iv_security_group_name = lv_security_group_name
                                                                    iv_vpc_id = av_vpc_id ).
    DATA(lo_describe_result) = ao_ec2->describesecuritygroups(
      it_groupids = VALUE /aws1/cl_ec2groupidstrlist_w=>tt_groupidstringlist(
                      ( NEW /aws1/cl_ec2groupidstrlist_w( lo_create_result->get_groupid( ) ) )
                    ) ).


    LOOP AT lo_describe_result->get_securitygroups( ) INTO DATA(lo_security_group).
      IF lo_security_group->get_groupname( ) = lv_security_group_name.
        DATA(lv_found) = abap_true.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
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
                        iv_name = 'vpc-id'
                        it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
                          ( NEW /aws1/cl_ec2valuestringlist_w( av_vpc_id ) )
                        )
                      ) )
                    ) ).


    LOOP AT lo_describe_result->get_securitygroups( ) INTO DATA(lo_security_group).
      IF lo_security_group->get_groupname( ) = lv_security_group_name.
        DATA(lv_found) = abap_true.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_false(
      act = lv_found
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

    LOOP AT lo_describe_result->get_securitygroups( ) INTO DATA(lo_security_group).
      IF lo_security_group->get_groupname( ) = lv_security_group_name.
        DATA(lv_found) = abap_true.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |Security Group { lv_security_group_name } should have been included in security group list| ).

    ao_ec2->deletesecuritygroup( iv_groupid = lo_create_result->get_groupid( ) ).
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
  METHOD wait_until_status_change.
    DO 96 TIMES.
      WAIT UP TO 5 SECONDS.
      DATA(lo_describe_result) = ao_ec2->describeinstances(
          it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
            ( NEW /aws1/cl_ec2instidstringlist_w( iv_instance_id ) )
          ) ).
      READ TABLE lo_describe_result->get_reservations( ) INTO DATA(lo_reservation) INDEX 1.
      READ TABLE lo_reservation->get_instances( ) INTO DATA(lo_describe_instance) INDEX 1.
      IF lo_describe_instance->get_state( )->get_name( ) = iv_required_status.
        EXIT.
      ENDIF.
    ENDDO.
    ov_current_status = lo_describe_instance->get_state( )->get_name( ).
  ENDMETHOD.
  METHOD run_instance.
    DATA(lo_create_result) = ao_ec2->runinstances(
        iv_imageid = get_ami_id( )
        iv_instancetype = 't3.micro'
        iv_maxcount = 1
        iv_mincount = 1
        iv_subnetid = iv_subnet_id
        it_tagspecifications = VALUE /aws1/cl_ec2tagspecification=>tt_tagspecificationlist(
          ( NEW /aws1/cl_ec2tagspecification(
              iv_resourcetype = 'instance'
              it_tags = VALUE /aws1/cl_ec2tag=>tt_taglist(
                ( NEW /aws1/cl_ec2tag( iv_key = 'Name' iv_value = |{ /awsex/cl_utils=>cv_asset_prefix }-ec2-test-instance| ) )
                ( NEW /aws1/cl_ec2tag( iv_key = 'convert_test' iv_value = 'true' ) )
              )
          ) )
        )
    ).
    READ TABLE lo_create_result->get_instances( ) INTO DATA(lo_instance) INDEX 1.
    ov_instance_id = lo_instance->get_instanceid( ).
    APPEND ov_instance_id TO at_instance_id.
  ENDMETHOD.
  METHOD terminate_instance.
    ao_ec2->terminateinstances00(
        it_instanceids = VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
          ( NEW /aws1/cl_ec2instidstringlist_w( iv_instance_id ) )
        ) ).
    wait_until_status_change( iv_instance_id = iv_instance_id
                              iv_required_status = 'terminated' ).
  ENDMETHOD.

  METHOD disassociate_address.
    DATA(lv_internet_gateway_id) = ao_ec2->createinternetgateway( )->get_internetgateway( )->get_internetgatewayid( ).
    ao_ec2->attachinternetgateway( iv_internetgatewayid = lv_internet_gateway_id
                                   iv_vpcid = av_vpc_id ).
    wait_until_status_change( iv_instance_id = av_instance_id
                              iv_required_status = 'running' ).
    DATA(lv_allocation_id) = ao_ec2->allocateaddress( iv_domain = 'vpc' )->get_allocationid( ).
    DATA(lo_associate_result) = ao_ec2->associateaddress(
        iv_allocationid = lv_allocation_id
        iv_instanceid = av_instance_id ).

    ao_ec2_actions->disassociate_address( lo_associate_result->get_associationid( ) ).

    " Verify the disassociation
    DATA(lo_describe_result) = ao_ec2->describeaddresses(
      it_allocationids = VALUE /aws1/cl_ec2allocationidlst_w=>tt_allocationidlist(
        ( NEW /aws1/cl_ec2allocationidlst_w( lv_allocation_id ) )
      ) ).
    READ TABLE lo_describe_result->get_addresses( ) INTO DATA(lo_address) INDEX 1.

    cl_abap_unit_assert=>assert_initial(
      act = lo_address->get_instanceid( )
      msg = |Elastic IP address should have been disassociated from instance| ).

    ao_ec2->releaseaddress( iv_allocationid = lv_allocation_id ).
    ao_ec2->detachinternetgateway( iv_internetgatewayid = lv_internet_gateway_id
                                   iv_vpcid = av_vpc_id ).
    ao_ec2->deleteinternetgateway( iv_internetgatewayid = lv_internet_gateway_id ).
  ENDMETHOD.

  METHOD terminate_instances.
    DATA(lv_instance_id) = run_instance( av_subnet_id ).
    wait_until_status_change( iv_instance_id = lv_instance_id
                              iv_required_status = 'running' ).

    DATA(lo_result) = ao_ec2_actions->terminate_instances(
      VALUE /aws1/cl_ec2instidstringlist_w=>tt_instanceidstringlist(
        ( NEW /aws1/cl_ec2instidstringlist_w( lv_instance_id ) )
      ) ).

    READ TABLE lo_result->get_terminatinginstances( ) INTO DATA(lo_terminating_instance) INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_terminating_instance->get_instanceid( )
      exp = lv_instance_id
      msg = |Instance should be in terminating instances list| ).

    wait_until_status_change( iv_instance_id = lv_instance_id
                              iv_required_status = 'terminated' ).
    DELETE at_instance_id WHERE table_line = lv_instance_id.
  ENDMETHOD.

  METHOD describe_images.
    DATA(lv_ami_id) = get_ami_id( ).
    DATA(lo_result) = ao_ec2_actions->describe_images(
      VALUE /aws1/cl_ec2imageidstrlist_w=>tt_imageidstringlist(
        ( NEW /aws1/cl_ec2imageidstrlist_w( lv_ami_id ) )
      ) ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_images( )
      msg = |Failed to retrieve image information| ).

    LOOP AT lo_result->get_images( ) INTO DATA(lo_image).
      IF lo_image->get_imageid( ) = lv_ami_id.
        DATA(lv_found) = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |AMI { lv_ami_id } should be in the images list| ).
  ENDMETHOD.

  METHOD describe_instance_types.
    DATA(lo_result) = ao_ec2_actions->describe_instance_types(
      VALUE /aws1/cl_ec2filter=>tt_filterlist(
        ( NEW /aws1/cl_ec2filter(
            iv_name = 'processor-info.supported-architecture'
            it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
              ( NEW /aws1/cl_ec2valuestringlist_w( 'x86_64' ) )
            )
        ) )
        ( NEW /aws1/cl_ec2filter(
            iv_name = 'instance-type'
            it_values = VALUE /aws1/cl_ec2valuestringlist_w=>tt_valuestringlist(
              ( NEW /aws1/cl_ec2valuestringlist_w( 't2.micro' ) )
              ( NEW /aws1/cl_ec2valuestringlist_w( 't3.micro' ) )
            )
        ) )
      ) ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_instancetypes( )
      msg = |Failed to retrieve instance type information| ).
  ENDMETHOD.

  METHOD create_vpc.
    CONSTANTS cv_cidr_block TYPE /aws1/ec2string VALUE '10.20.0.0/16'.
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_vpc_name) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.

    " Create VPC with tags
    DATA(lo_result) = ao_ec2->createvpc(
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

    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_vpc( )->get_vpcid( )
      msg = |Failed to create VPC| ).

    DATA(lv_test_vpc_id) = lo_result->get_vpc( )->get_vpcid( ).

    " Test the action method by calling it
    DATA(lo_action_result) = ao_ec2_actions->create_vpc( cv_cidr_block ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_action_result->get_vpc( )->get_vpcid( )
      msg = |Failed to create VPC via action method| ).

    " Clean up test VPCs
    DO 10 TIMES.
      TRY.
          ao_ec2->deletevpc( iv_vpcid = lv_test_vpc_id ).
          EXIT.
        CATCH /aws1/cx_rt_service_generic.
          WAIT UP TO 5 SECONDS.
      ENDTRY.
    ENDDO.

    DO 10 TIMES.
      TRY.
          ao_ec2->deletevpc( iv_vpcid = lo_action_result->get_vpc( )->get_vpcid( ) ).
          EXIT.
        CATCH /aws1/cx_rt_service_generic.
          WAIT UP TO 5 SECONDS.
      ENDTRY.
    ENDDO.
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

  METHOD create_vpc_endpoint.
    " Get route table ID from the VPC
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
    DATA(lv_route_table_id) = lo_route_table->get_routetableid( ).

    " Create VPC endpoint
    DATA(lv_region) = ao_session->get_region( ).
    DATA(lv_service_name) = |com.amazonaws.{ lv_region }.s3|.

    DATA(lo_result) = ao_ec2_actions->create_vpc_endpoint(
      iv_vpc_id = av_vpc_id
      iv_service_name = lv_service_name
      it_route_table_ids = VALUE /aws1/cl_ec2vpcendptroutetbl00=>tt_vpcendpointroutetableidlist(
        ( NEW /aws1/cl_ec2vpcendptroutetbl00( lv_route_table_id ) )
      ) ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_vpcendpoint( )->get_vpcendpointid( )
      msg = |Failed to create VPC endpoint| ).

    DATA(lv_vpc_endpoint_id) = lo_result->get_vpcendpoint( )->get_vpcendpointid( ).

    " Clean up
    ao_ec2->deletevpcendpoints(
      it_vpcendpointids = VALUE /aws1/cl_ec2vpcendptidlist_w=>tt_vpcendpointidlist(
        ( NEW /aws1/cl_ec2vpcendptidlist_w( lv_vpc_endpoint_id ) )
      ) ).
  ENDMETHOD.

  METHOD delete_vpc_endpoints.
    " Create a VPC endpoint first
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
    DATA(lv_route_table_id) = lo_route_table->get_routetableid( ).

    DATA(lv_region) = ao_session->get_region( ).
    DATA(lv_service_name) = |com.amazonaws.{ lv_region }.s3|.

    DATA(lo_create_result) = ao_ec2->createvpcendpoint(
      iv_vpcid = av_vpc_id
      iv_servicename = lv_service_name
      it_routetableids = VALUE /aws1/cl_ec2vpcendptroutetbl00=>tt_vpcendpointroutetableidlist(
        ( NEW /aws1/cl_ec2vpcendptroutetbl00( lv_route_table_id ) )
      ) ).

    DATA(lv_vpc_endpoint_id) = lo_create_result->get_vpcendpoint( )->get_vpcendpointid( ).

    " Delete the VPC endpoint
    ao_ec2_actions->delete_vpc_endpoints(
      VALUE /aws1/cl_ec2vpcendptidlist_w=>tt_vpcendpointidlist(
        ( NEW /aws1/cl_ec2vpcendptidlist_w( lv_vpc_endpoint_id ) )
      ) ).

    " Verify deletion - wait a bit for deletion to complete
    WAIT UP TO 5 SECONDS.

    DATA(lo_describe_result) = ao_ec2->describevpcendpoints(
      it_vpcendpointids = VALUE /aws1/cl_ec2vpcendptidlist_w=>tt_vpcendpointidlist(
        ( NEW /aws1/cl_ec2vpcendptidlist_w( lv_vpc_endpoint_id ) )
      ) ).

    READ TABLE lo_describe_result->get_vpcendpoints( ) INTO DATA(lo_endpoint) INDEX 1.

    cl_abap_unit_assert=>assert_equals(
      act = lo_endpoint->get_state( )
      exp = 'deleted'
      msg = |VPC endpoint should be deleted or deleting| ).
  ENDMETHOD.

  METHOD delete_vpc.
    CONSTANTS cv_cidr_block TYPE /aws1/ec2string VALUE '10.30.0.0/16'.
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    DATA(lv_vpc_name) = |{ /awsex/cl_utils=>cv_asset_prefix }-{ lv_uuid }|.

    " Create VPC with tags
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

    " Wait for VPC to be available
    WAIT UP TO 5 SECONDS.

    " Test the action method
    ao_ec2_actions->delete_vpc( lv_test_vpc_id ).

    " Verify deletion
    TRY.
        ao_ec2->describevpcs(
          it_vpcids = VALUE /aws1/cl_ec2vpcidstringlist_w=>tt_vpcidstringlist(
            ( NEW /aws1/cl_ec2vpcidstringlist_w( lv_test_vpc_id ) )
          ) ).
        DATA(lv_vpc_exists) = abap_true.
      CATCH /aws1/cx_rt_service_generic.
        lv_vpc_exists = abap_false.
    ENDTRY.

    cl_abap_unit_assert=>assert_false(
      act = lv_vpc_exists
      msg = |VPC should have been deleted| ).
  ENDMETHOD.
ENDCLASS.
