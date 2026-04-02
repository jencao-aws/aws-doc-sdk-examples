" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS /awsex/cl_iot_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    " snippet-start:[iot.abapv1.create_thing]
    METHODS create_thing
      IMPORTING
        !iv_thing_name        TYPE /aws1/iotthingname
      RETURNING
        VALUE(oo_result)      TYPE REF TO /aws1/cl_iotcreatethingrsp
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.create_thing]

    " snippet-start:[iot.abapv1.list_things]
    METHODS list_things
      RETURNING
        VALUE(oo_result)      TYPE REF TO /aws1/cl_iotlistthingsresponse
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.list_things]

    " snippet-start:[iot.abapv1.create_keys_and_certificate]
    METHODS create_keys_and_certificate
      RETURNING
        VALUE(oo_result)      TYPE REF TO /aws1/cl_iotcrekeysandcertrsp
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.create_keys_and_certificate]

    " snippet-start:[iot.abapv1.attach_thing_principal]
    METHODS attach_thing_principal
      IMPORTING
        !iv_thing_name        TYPE /aws1/iotthingname
        !iv_principal         TYPE /aws1/iotprincipal
      RETURNING
        VALUE(oo_result)      TYPE REF TO /aws1/cl_iotattachthgprincrsp
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.attach_thing_principal]

    " snippet-start:[iot.abapv1.describe_endpoint]
    METHODS describe_endpoint
      IMPORTING
        !iv_endpoint_type     TYPE /aws1/iotendpointtype OPTIONAL
      RETURNING
        VALUE(ov_endpoint)    TYPE /aws1/iotendpointaddress
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.describe_endpoint]

    " snippet-start:[iot.abapv1.list_certificates]
    METHODS list_certificates
      RETURNING
        VALUE(oo_result)      TYPE REF TO /aws1/cl_iotlistcertsresponse
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.list_certificates]

    " snippet-start:[iot.abapv1.detach_thing_principal]
    METHODS detach_thing_principal
      IMPORTING
        !iv_thing_name        TYPE /aws1/iotthingname
        !iv_principal         TYPE /aws1/iotprincipal
      RETURNING
        VALUE(oo_result)      TYPE REF TO /aws1/cl_iotdetachthgprincrsp
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.detach_thing_principal]

    " snippet-start:[iot.abapv1.delete_certificate]
    METHODS delete_certificate
      IMPORTING
        !iv_certificate_id    TYPE /aws1/iotcertificateid
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.delete_certificate]

    " snippet-start:[iot.abapv1.create_topic_rule]
    METHODS create_topic_rule
      IMPORTING
        !iv_rule_name         TYPE /aws1/iotrulename
        !iv_topic             TYPE /aws1/iottopic
        !iv_sns_action_arn    TYPE /aws1/iotsnstopicarn
        !iv_role_arn          TYPE /aws1/iotawsarn
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.create_topic_rule]

    " snippet-start:[iot.abapv1.list_topic_rules]
    METHODS list_topic_rules
      RETURNING
        VALUE(oo_result)      TYPE REF TO /aws1/cl_iotlisttopicrulesrsp
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.list_topic_rules]

    " snippet-start:[iot.abapv1.search_index]
    METHODS search_index
      IMPORTING
        !iv_query             TYPE /aws1/iotquerystring
      RETURNING
        VALUE(oo_result)      TYPE REF TO /aws1/cl_iotsearchindexrsp
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.search_index]

    " snippet-start:[iot.abapv1.update_indexing_configuration]
    METHODS update_indexing_configuration
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.update_indexing_configuration]

    " snippet-start:[iot.abapv1.delete_thing]
    METHODS delete_thing
      IMPORTING
        !iv_thing_name        TYPE /aws1/iotthingname
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.delete_thing]

    " snippet-start:[iot.abapv1.delete_topic_rule]
    METHODS delete_topic_rule
      IMPORTING
        !iv_rule_name         TYPE /aws1/iotrulename
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.delete_topic_rule]

    " snippet-start:[iot.abapv1.update_thing_shadow]
    METHODS update_thing_shadow
      IMPORTING
        !iv_thing_name        TYPE /aws1/iopthingname
        !iv_shadow_state      TYPE /aws1/iopjsondocument
      RETURNING
        VALUE(oo_result)      TYPE REF TO /aws1/cl_iopupdatethgshadowrsp
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.update_thing_shadow]

    " snippet-start:[iot.abapv1.get_thing_shadow]
    METHODS get_thing_shadow
      IMPORTING
        !iv_thing_name        TYPE /aws1/iopthingname
      RETURNING
        VALUE(oo_result)      TYPE REF TO /aws1/cl_iopgetthingshadowrsp
      RAISING
        /aws1/cx_rt_generic .
    " snippet-end:[iot.abapv1.get_thing_shadow]

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /AWSEX/CL_IOT_ACTIONS IMPLEMENTATION.


  METHOD create_thing.
    " iv_thing_name = 'MyThing'
    
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.create_thing]
    TRY.
        oo_result = lo_iot->creatething( iv_thingname = iv_thing_name ).
        MESSAGE 'Thing created successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        MESSAGE 'Thing already exists.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.create_thing]
  ENDMETHOD.


  METHOD list_things.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.list_things]
    TRY.
        oo_result = lo_iot->listthings( ).
        DATA(lt_things) = oo_result->get_things( ).
        MESSAGE |Found { lines( lt_things ) } thing(s).| TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.list_things]
  ENDMETHOD.


  METHOD create_keys_and_certificate.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.create_keys_and_certificate]
    TRY.
        oo_result = lo_iot->createkeysandcertificate( iv_setasactive = abap_true ).
        MESSAGE 'Certificate created successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.create_keys_and_certificate]
  ENDMETHOD.


  METHOD attach_thing_principal.
    " iv_thing_name = 'MyThing'
    " iv_principal = 'arn:aws:iot:us-west-2:123456789012:cert/certificateId'
    
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.attach_thing_principal]
    TRY.
        oo_result = lo_iot->attachthingprincipal(
          iv_thingname = iv_thing_name
          iv_principal = iv_principal
        ).
        MESSAGE 'Principal attached to thing successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresourcenotfoundex.
        MESSAGE 'Thing or certificate not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.attach_thing_principal]
  ENDMETHOD.


  METHOD describe_endpoint.
    " iv_endpoint_type = 'iot:Data-ATS'
    
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.describe_endpoint]
    TRY.
        DATA(lo_result) = lo_iot->describeendpoint( iv_endpointtype = iv_endpoint_type ).
        ov_endpoint = lo_result->get_endpointaddress( ).
        MESSAGE |Endpoint: { ov_endpoint }| TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.describe_endpoint]
  ENDMETHOD.


  METHOD list_certificates.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.list_certificates]
    TRY.
        oo_result = lo_iot->listcertificates( ).
        DATA(lt_certificates) = oo_result->get_certificates( ).
        MESSAGE |Found { lines( lt_certificates ) } certificate(s).| TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.list_certificates]
  ENDMETHOD.


  METHOD detach_thing_principal.
    " iv_thing_name = 'MyThing'
    " iv_principal = 'arn:aws:iot:us-west-2:123456789012:cert/certificateId'
    
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.detach_thing_principal]
    TRY.
        oo_result = lo_iot->detachthingprincipal(
          iv_thingname = iv_thing_name
          iv_principal = iv_principal
        ).
        MESSAGE 'Principal detached from thing successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresourcenotfoundex.
        MESSAGE 'Thing or certificate not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.detach_thing_principal]
  ENDMETHOD.


  METHOD delete_certificate.
    " iv_certificate_id = 'certificateId123'
    
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.delete_certificate]
    TRY.
        lo_iot->updatecertificate(
          iv_certificateid = iv_certificate_id
          iv_newstatus = 'INACTIVE'
        ).
        lo_iot->deletecertificate( iv_certificateid = iv_certificate_id ).
        MESSAGE 'Certificate deleted successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresourcenotfoundex.
        MESSAGE 'Certificate not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.delete_certificate]
  ENDMETHOD.


  METHOD create_topic_rule.
    " iv_rule_name = 'MyTopicRule'
    " iv_topic = 'my/topic'
    " iv_sns_action_arn = 'arn:aws:sns:us-west-2:123456789012:MyTopic'
    " iv_role_arn = 'arn:aws:iam::123456789012:role/MyIoTRole'
    
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.create_topic_rule]
    TRY.
        DATA(lt_actions) = VALUE /aws1/cl_iotaction=>tt_actionlist(
          ( NEW /aws1/cl_iotaction(
              io_sns = NEW /aws1/cl_iotsnsaction(
                iv_targetarn = iv_sns_action_arn
                iv_rolearn = iv_role_arn
              )
            )
          )
        ).

        DATA(lo_rule_payload) = NEW /aws1/cl_iottopicrulepayload(
          iv_sql = |SELECT * FROM '{ iv_topic }'|
          it_actions = lt_actions
        ).

        lo_iot->createtopicrule(
          iv_rulename = iv_rule_name
          io_topicrulepayload = lo_rule_payload
        ).
        MESSAGE 'Topic rule created successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        MESSAGE 'Topic rule already exists.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.create_topic_rule]
  ENDMETHOD.


  METHOD list_topic_rules.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.list_topic_rules]
    TRY.
        oo_result = lo_iot->listtopicrules( ).
        DATA(lt_rules) = oo_result->get_rules( ).
        MESSAGE |Found { lines( lt_rules ) } topic rule(s).| TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.list_topic_rules]
  ENDMETHOD.


  METHOD search_index.
    " iv_query = 'thingName:MyThing*'
    
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.search_index]
    TRY.
        oo_result = lo_iot->searchindex( iv_querystring = iv_query ).
        DATA(lt_things) = oo_result->get_things( ).
        MESSAGE |Found { lines( lt_things ) } thing(s) matching query.| TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.search_index]
  ENDMETHOD.


  METHOD update_indexing_configuration.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.update_indexing_configuration]
    TRY.
        DATA(lo_thing_indexing_config) = NEW /aws1/cl_iotthingindexingconf(
          iv_thingindexingmode = 'REGISTRY'
        ).

        lo_iot->updateindexingconfiguration(
          io_thingindexingconfiguration = lo_thing_indexing_config
        ).
        MESSAGE 'Indexing configuration updated successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotthrottlingex.
        MESSAGE 'Request throttled. Please try again later.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.update_indexing_configuration]
  ENDMETHOD.


  METHOD delete_thing.
    " iv_thing_name = 'MyThing'
    
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.delete_thing]
    TRY.
        lo_iot->deletething( iv_thingname = iv_thing_name ).
        MESSAGE 'Thing deleted successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresourcenotfoundex.
        MESSAGE 'Thing not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.delete_thing]
  ENDMETHOD.


  METHOD delete_topic_rule.
    " iv_rule_name = 'MyTopicRule'
    
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iot) = /aws1/cl_iot_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.delete_topic_rule]
    TRY.
        lo_iot->deletetopicrule( iv_rulename = iv_rule_name ).
        MESSAGE 'Topic rule deleted successfully.' TYPE 'I'.
      CATCH /aws1/cx_iotresourcenotfoundex.
        MESSAGE 'Topic rule not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.delete_topic_rule]
  ENDMETHOD.


  METHOD update_thing_shadow.
    " iv_thing_name = 'MyThing'
    " iv_shadow_state = '{"state":{"desired":{"color":"red"}}}'
    
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iop) = /aws1/cl_iop_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.update_thing_shadow]
    TRY.
        oo_result = lo_iop->updatethingshadow(
          iv_thingname = iv_thing_name
          iv_payload = iv_shadow_state
        ).
        MESSAGE 'Thing shadow updated successfully.' TYPE 'I'.
      CATCH /aws1/cx_iopresourcenotfoundex.
        MESSAGE 'Thing not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.update_thing_shadow]
  ENDMETHOD.


  METHOD get_thing_shadow.
    " iv_thing_name = 'MyThing'
    
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iop) = /aws1/cl_iop_factory=>create( lo_session ).

    " snippet-start:[iot.abapv1.get_thing_shadow]
    TRY.
        oo_result = lo_iop->getthingshadow( iv_thingname = iv_thing_name ).
        DATA(lv_shadow) = oo_result->get_payload( ).
        MESSAGE 'Thing shadow retrieved successfully.' TYPE 'I'.
      CATCH /aws1/cx_iopresourcenotfoundex.
        MESSAGE 'Thing shadow not found.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iot.abapv1.get_thing_shadow]
  ENDMETHOD.
ENDCLASS.
