" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_frh_actions DEFINITION DEFERRED.
CLASS /awsex/cl_frh_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_frh_actions.

CLASS ltc_awsex_cl_frh_actions DEFINITION FOR TESTING DURATION LONG RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_frh TYPE REF TO /aws1/if_frh.
    CLASS-DATA ao_cwt TYPE REF TO /aws1/if_cwt.
    CLASS-DATA ao_s3 TYPE REF TO /aws1/if_s3.
    CLASS-DATA ao_iam TYPE REF TO /aws1/if_iam.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_frh_actions TYPE REF TO /awsex/cl_frh_actions.
    CLASS-DATA av_delivery_stream_name TYPE /aws1/frhdeliverystreamname.
    CLASS-DATA av_bucket_name TYPE /aws1/s3_bucketname.
    CLASS-DATA av_role_arn TYPE /aws1/frhrolearn.
    CLASS-DATA av_role_name TYPE /aws1/iamrolename.

    METHODS: put_record FOR TESTING RAISING /aws1/cx_rt_generic,
      put_record_batch FOR TESTING RAISING /aws1/cx_rt_generic.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.

    METHODS wait_for_stream_active
      IMPORTING
        iv_stream_name TYPE /aws1/frhdeliverystreamname
      RAISING
        /aws1/cx_rt_generic.

ENDCLASS.

CLASS ltc_awsex_cl_frh_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_frh = /aws1/cl_frh_factory=>create( ao_session ).
    ao_cwt = /aws1/cl_cwt_factory=>create( ao_session ).
    ao_s3 = /aws1/cl_s3_factory=>create( ao_session ).
    ao_iam = /aws1/cl_iam_factory=>create( ao_session ).
    ao_frh_actions = NEW /awsex/cl_frh_actions( ).

    " Generate unique names
    DATA(lv_uuid) = /aws1/cl_rt_util=>uuid_get_c32( ).
    DATA lv_uuid_string TYPE string.
    lv_uuid_string = lv_uuid.
    av_delivery_stream_name = |frh-ex-stream-{ lv_uuid_string(8) }|.
    av_bucket_name = |frh-ex-bucket-{ lv_uuid_string(8) }|.
    av_role_name = |frh-ex-role-{ lv_uuid_string(8) }|.

    " Create S3 bucket for Firehose destination
    TRY.
        /awsex/cl_utils=>create_bucket(
          iv_bucket = av_bucket_name
          io_s3 = ao_s3
          io_session = ao_session
        ).
      CATCH /aws1/cx_s3_bucketalrdyexists INTO DATA(lo_exists).
        " Bucket already exists, continue
      CATCH /aws1/cx_s3_bucketalrdyownedbyu INTO DATA(lo_owned).
        " Bucket already owned by you, continue
    ENDTRY.

    " Create IAM role for Firehose with S3 permissions
    DATA(lv_trust_policy) = `{` &&
      `"Version":"2012-10-17",` &&
      `"Statement":[{` &&
        `"Effect":"Allow",` &&
        `"Principal":{"Service":"firehose.amazonaws.com"},` &&
        `"Action":"sts:AssumeRole"` &&
      `}]` &&
    `}`.

    TRY.
        DATA(lo_create_role_result) = ao_iam->createrole(
          iv_rolename = av_role_name
          iv_assumerolepolicydocument = lv_trust_policy
          it_tags = VALUE /aws1/cl_iamtag=>tt_taglisttype(
            ( NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).
        av_role_arn = lo_create_role_result->get_role( )->get_arn( ).

        " Attach policy to allow Firehose to write to S3
        DATA(lv_policy_document) = `{` &&
          `"Version":"2012-10-17",` &&
          `"Statement":[{` &&
            `"Effect":"Allow",` &&
            `"Action":["s3:PutObject","s3:GetObject","s3:ListBucket"],` &&
            `"Resource":["arn:aws:s3:::` && av_bucket_name && `","arn:aws:s3:::` && av_bucket_name && `/*"]` &&
          `}]` &&
        `}`.

        ao_iam->putrolepolicy(
          iv_rolename = av_role_name
          iv_policyname = |frh-s3-policy|
          iv_policydocument = lv_policy_document
        ).

        " Wait for IAM role to propagate
        WAIT UP TO 10 SECONDS.

      CATCH /aws1/cx_iamentityalrdyexists INTO DATA(lo_role_exists).
        " Role already exists, get its ARN
        DATA(lo_get_role) = ao_iam->getrole( iv_rolename = av_role_name ).
        av_role_arn = lo_get_role->get_role( )->get_arn( ).
    ENDTRY.

    " Create Firehose delivery stream
    TRY.
        ao_frh->createdeliverystream(
          iv_deliverystreamname = av_delivery_stream_name
          iv_deliverystreamtype = 'DirectPut'
          io_extendeds3destinationconfiguration = NEW /aws1/cl_frhextendeds3dstconf(
            iv_bucketarn = |arn:aws:s3:::{ av_bucket_name }|
            iv_rolearn = av_role_arn
            io_bufferinghints = NEW /aws1/cl_frhbufferinghints(
              iv_sizeinmbs = 5
              iv_intervalinseconds = 300
            )
            iv_compressionformat = 'UNCOMPRESSED'
          )
          it_tags = VALUE /aws1/cl_frhtag=>tt_tagdeliverystreaminputtaglist(
            ( NEW /aws1/cl_frhtag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).

      CATCH /aws1/cx_frhresourceinuseex INTO DATA(lo_stream_exists).
        " Stream already exists, continue
    ENDTRY.

    " Wait for stream to become active
    TRY.
        wait_for_stream_active( av_delivery_stream_name ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_wait_error).
        " Fail the test if stream doesn't become active
        cl_abap_unit_assert=>fail( msg = |Failed to create active stream: { lo_wait_error->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.

  METHOD class_teardown.
    " Delete delivery stream
    IF av_delivery_stream_name IS NOT INITIAL.
      TRY.
          ao_frh->deletedeliverystream(
            iv_deliverystreamname = av_delivery_stream_name
          ).
        CATCH /aws1/cx_frhresourcenotfoundex.
          " Stream doesn't exist, continue
      ENDTRY.
    ENDIF.

    " Delete IAM role policy and role
    IF av_role_name IS NOT INITIAL.
      TRY.
          ao_iam->deleterolepolicy(
            iv_rolename = av_role_name
            iv_policyname = |frh-s3-policy|
          ).
        CATCH /aws1/cx_iamnosuchentityex.
          " Policy doesn't exist, continue
      ENDTRY.

      TRY.
          ao_iam->deleterole( iv_rolename = av_role_name ).
        CATCH /aws1/cx_iamnosuchentityex.
          " Role doesn't exist, continue
      ENDTRY.
    ENDIF.

    " Note: S3 bucket is not deleted here because the delivery stream may take time to clean up.
    " The bucket is tagged with 'convert_test' for manual cleanup.

  ENDMETHOD.

  METHOD put_record.
    DATA lv_test_data TYPE /aws1/frhdata.
    " Example: Test data as JSON string
    lv_test_data = /aws1/cl_rt_util=>string_to_xstring( `{"test":"data","timestamp":"2024-01-01"}` ).

    DATA(lo_result) = ao_frh_actions->put_record(
      iv_delivery_stream_name = av_delivery_stream_name
      iv_data = lv_test_data
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Put record should return a result'
    ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_recordid( )
      msg = 'Record ID should not be empty'
    ).

  ENDMETHOD.

  METHOD put_record_batch.
    DATA lt_records TYPE /aws1/cl_frhrecord=>tt_putrecordbatchreqentrylist.
    DATA lv_data TYPE /aws1/frhdata.

    " Create batch of test records
    DO 10 TIMES.
      DATA(lv_json) = |{ '{"test":"batch_data","index":"' }{ sy-index }{ '","timestamp":"2024-01-01"}' }|.
      lv_data = /aws1/cl_rt_util=>string_to_xstring( lv_json ).
      APPEND NEW /aws1/cl_frhrecord( iv_data = lv_data ) TO lt_records.
    ENDDO.

    DATA(lo_result) = ao_frh_actions->put_record_batch(
      iv_delivery_stream_name = av_delivery_stream_name
      it_records = lt_records
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Put record batch should return a result'
    ).

    DATA(lv_failed_count) = lo_result->get_failedputcount( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_failed_count
      exp = 0
      msg = |Batch should not have failed records. Failed count: { lv_failed_count }|
    ).

  ENDMETHOD.

  METHOD wait_for_stream_active.
    DATA lv_max_wait TYPE i VALUE 300. " 5 minutes max
    DATA lv_waited TYPE i VALUE 0.
    DATA lv_status TYPE /aws1/frhdeliverystreamstatus.

    DO.
      TRY.
          DATA(lo_describe) = ao_frh->describedeliverystream(
            iv_deliverystreamname = iv_stream_name
          ).
          lv_status = lo_describe->get_deliverystreamdescription( )->get_deliverystreamstatus( ).

          IF lv_status = 'ACTIVE'.
            EXIT.
          ENDIF.

        CATCH /aws1/cx_frhresourcenotfoundex.
          " Stream not found yet, wait
      ENDTRY.

      IF lv_waited >= lv_max_wait.
        RAISE EXCEPTION TYPE /aws1/cx_rt_generic
          EXPORTING
            av_err_text = 'Timeout waiting for delivery stream to become active'.
      ENDIF.

      WAIT UP TO 5 SECONDS.
      lv_waited = lv_waited + 5.
    ENDDO.

  ENDMETHOD.

ENDCLASS.
