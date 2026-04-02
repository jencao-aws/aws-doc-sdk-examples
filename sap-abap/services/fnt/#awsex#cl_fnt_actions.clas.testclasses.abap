" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_fnt_actions DEFINITION DEFERRED.
CLASS /awsex/cl_fnt_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_fnt_actions.

CLASS ltc_awsex_cl_fnt_actions DEFINITION FOR TESTING DURATION LONG RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_fnt TYPE REF TO /aws1/if_fnt.
    CLASS-DATA ao_s3 TYPE REF TO /aws1/if_s3.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_fnt_actions TYPE REF TO /awsex/cl_fnt_actions.
    CLASS-DATA av_distribution_id TYPE /aws1/fntstring.
    CLASS-DATA av_bucket_name TYPE /aws1/s3_bucketname.
    CLASS-DATA av_oac_id TYPE /aws1/fntstring.
    CLASS-DATA av_original_comment TYPE /aws1/fntcommenttype.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.

    METHODS list_distributions FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS update_distribution FOR TESTING RAISING /aws1/cx_rt_generic.

ENDCLASS.

CLASS ltc_awsex_cl_fnt_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_fnt = /aws1/cl_fnt_factory=>create( ao_session ).
    ao_s3 = /aws1/cl_s3_factory=>create( ao_session ).
    ao_fnt_actions = NEW /awsex/cl_fnt_actions( ).

    " Generate unique bucket name
    DATA(lv_account_id) = ao_session->get_account_id( ).
    DATA(lv_uuid) = /awsex/cl_utils=>get_random_string( ).
    av_bucket_name = |sap-abap-fnt-test-{ lv_account_id }-{ lv_uuid }|.
    av_bucket_name = to_lower( av_bucket_name ).

    " Shorten bucket name if needed (max 63 characters)
    IF strlen( av_bucket_name ) > 63.
      av_bucket_name = substring( val = av_bucket_name len = 63 ).
    ENDIF.

    TRY.
        " Step 1: Create S3 bucket
        MESSAGE 'Creating S3 bucket for CloudFront test...' TYPE 'I'.
        /awsex/cl_utils=>create_bucket(
          iv_bucket = av_bucket_name
          io_s3 = ao_s3
          io_session = ao_session ).

        " Tag the S3 bucket
        DATA lt_tags TYPE /aws1/cl_s3_tag=>tt_tagset.
        APPEND NEW /aws1/cl_s3_tag( iv_key = 'convert_test' iv_value = 'true' ) TO lt_tags.
        APPEND NEW /aws1/cl_s3_tag( iv_key = 'service' iv_value = 'cloudfront' ) TO lt_tags.

        ao_s3->putbuckettagging(
          iv_bucket = av_bucket_name
          io_tagging = NEW /aws1/cl_s3_tagging( it_tagset = lt_tags ) ).

        " Upload a test file to the bucket
        DATA lv_test_content TYPE string.
        lv_test_content = '<html><body><h1>CloudFront Test</h1></body></html>'.
        DATA lv_body TYPE xstring.
        lv_body = cl_abap_codepage=>convert_to( source = lv_test_content ).
        ao_s3->putobject(
          iv_bucket = av_bucket_name
          iv_key = 'index.html'
          iv_body = lv_body ).

        " Step 2: Create Origin Access Control
        MESSAGE 'Creating Origin Access Control...' TYPE 'I'.
        DATA(lo_oac_config) = NEW /aws1/cl_fntoriginaccctlconfig(
          iv_name = |oac-{ av_bucket_name }|
          iv_signingprotocol = 'sigv4'
          iv_signingbehavior = 'always'
          iv_originaccessctlorigintype = 's3'
        ).

        DATA(lo_oac_result) = ao_fnt->createoriginaccesscontrol(
          io_originaccesscontrolconfig = lo_oac_config ).

        av_oac_id = lo_oac_result->get_originaccesscontrol( )->get_id( ).
        MESSAGE 'Created Origin Access Control: ' && av_oac_id TYPE 'I'.

        " Tag the OAC using CloudFront TagResource
        DATA lt_fnt_tags TYPE /aws1/cl_fnttag=>tt_taglist.
        APPEND NEW /aws1/cl_fnttag( iv_key = 'convert_test' iv_value = 'true' ) TO lt_fnt_tags.
        APPEND NEW /aws1/cl_fnttag( iv_key = 'service' iv_value = 'cloudfront' ) TO lt_fnt_tags.

        DATA(lv_oac_arn) = |arn:aws:cloudfront::{ lv_account_id }:origin-access-control/{ av_oac_id }|.
        ao_fnt->tagresource(
          iv_resource = lv_oac_arn
          io_tags = NEW /aws1/cl_fnttags( it_items = lt_fnt_tags ) ).

        " Step 3: Create CloudFront Distribution
        MESSAGE 'Creating CloudFront distribution (this takes 5-15 minutes)...' TYPE 'I'.

        " Create timestamp for caller reference
        DATA lv_timestamp TYPE timestamp.
        GET TIME STAMP FIELD lv_timestamp.
        DATA(lv_caller_ref) = |fnt-test-{ lv_timestamp }|.

        " Build distribution configuration
        DATA(lo_origin) = NEW /aws1/cl_fntorigin(
          iv_id = |S3-{ av_bucket_name }|
          iv_domainname = |{ av_bucket_name }.s3.amazonaws.com|
          io_s3originconfig = NEW /aws1/cl_fnts3originconfig(
            iv_originaccessidentity = ''
            iv_originreadtimeout = 30 )
          iv_originaccesscontrolid = av_oac_id
          iv_connectionattempts = 3
          iv_connectiontimeout = 10
        ).

        DATA lt_origins TYPE /aws1/cl_fntorigin=>tt_originlist.
        APPEND lo_origin TO lt_origins.

        DATA(lo_origins) = NEW /aws1/cl_fntorigins(
          it_items = lt_origins
          iv_quantity = 1 ).

        " Create default cache behavior
        DATA(lo_fwd_values) = NEW /aws1/cl_fntforwardedvalues(
          iv_querystring = abap_false
          io_cookies = NEW /aws1/cl_fntcookiepreference( iv_forward = 'none' )
        ).

        DATA(lo_trusted_signers) = NEW /aws1/cl_fnttrustedsigners(
          iv_enabled = abap_false
          iv_quantity = 0 ).

        DATA(lo_default_behavior) = NEW /aws1/cl_fntdefaultcachebehav(
          iv_targetoriginid = |S3-{ av_bucket_name }|
          iv_viewerprotocolpolicy = 'redirect-to-https'
          io_trustedsigners = lo_trusted_signers
          io_forwardedvalues = lo_fwd_values
          iv_minttl = 0
          iv_compress = abap_true ).

        " Create distribution config
        DATA(lo_dist_config) = NEW /aws1/cl_fntdistributionconfig(
          iv_callerreference = lv_caller_ref
          io_origins = lo_origins
          io_defaultcachebehavior = lo_default_behavior
          iv_comment = 'Test distribution for ABAP SDK examples'
          iv_enabled = abap_true ).

        DATA(lo_dist_result) = ao_fnt->createdistribution(
          io_distributionconfig = lo_dist_config ).

        av_distribution_id = lo_dist_result->get_distribution( )->get_id( ).
        DATA(lv_domain_name) = lo_dist_result->get_distribution( )->get_domainname( ).
        MESSAGE 'Created distribution: ' && av_distribution_id TYPE 'I'.
        MESSAGE 'Domain: ' && lv_domain_name TYPE 'I'.

        " Tag the distribution
        DATA(lv_dist_arn) = |arn:aws:cloudfront::{ lv_account_id }:distribution/{ av_distribution_id }|.
        ao_fnt->tagresource(
          iv_resource = lv_dist_arn
          io_tags = NEW /aws1/cl_fnttags( it_items = lt_fnt_tags ) ).

        " Step 4: Update S3 bucket policy to allow CloudFront access
        MESSAGE 'Updating S3 bucket policy...' TYPE 'I'.
        DATA(lv_bucket_policy) = 
          '{"Version":"2012-10-17",' &&
          '"Statement":[{' &&
          '"Sid":"AllowCloudFrontServicePrincipal",' &&
          '"Effect":"Allow",' &&
          '"Principal":{"Service":"cloudfront.amazonaws.com"},' &&
          '"Action":"s3:GetObject",' &&
          '"Resource":"arn:aws:s3:::' && av_bucket_name && '/*",' &&
          '"Condition":{"StringEquals":{' &&
          '"AWS:SourceArn":"' && lv_dist_arn && '"}}}]}' .

        ao_s3->putbucketpolicy(
          iv_bucket = av_bucket_name
          iv_policy = lv_bucket_policy ).

        " Step 5: Wait for distribution deployment
        MESSAGE 'Waiting for distribution deployment (5-15 minutes)...' TYPE 'I'.

        " Poll distribution status
        DATA lv_deployed TYPE abap_bool VALUE abap_false.
        DATA lv_max_attempts TYPE i VALUE 180.
        DATA lv_attempt TYPE i VALUE 0.

        WHILE lv_deployed = abap_false AND lv_attempt < lv_max_attempts.
          WAIT UP TO 10 SECONDS.
          lv_attempt = lv_attempt + 1.

          TRY.
              DATA(lo_check_dist) = ao_fnt->getdistribution( iv_id = av_distribution_id ).
              DATA(lv_status) = lo_check_dist->get_distribution( )->get_status( ).

              IF lv_status = 'Deployed'.
                lv_deployed = abap_true.
                MESSAGE 'Distribution deployed successfully.' TYPE 'I'.
              ELSE.
                " Log progress every 30 seconds (every 3 attempts)
                IF lv_attempt MOD 3 = 0.
                  MESSAGE |Deployment in progress... Status: { lv_status } (attempt { lv_attempt }/{ lv_max_attempts })| TYPE 'I'.
                ENDIF.
              ENDIF.
            CATCH /aws1/cx_rt_generic.
              " Continue polling
          ENDTRY.
        ENDWHILE.

        IF lv_deployed = abap_false.
          cl_abap_unit_assert=>fail( msg = 'Distribution deployment timed out after 30 minutes.' ).
        ENDIF.

        " Save original comment for restoration
        DATA(lo_config_result) = ao_fnt->getdistributionconfig( iv_id = av_distribution_id ).
        av_original_comment = lo_config_result->get_distributionconfig( )->get_comment( ).

        MESSAGE 'CloudFront test resources created successfully.' TYPE 'I'.

      CATCH /aws1/cx_s3_bucketalreadyexists INTO DATA(lo_bucket_exists).
        DATA(lv_error) = |Bucket already exists: { lo_bucket_exists->if_message~get_text( ) }|.
        cl_abap_unit_assert=>fail( msg = lv_error ).
      CATCH /aws1/cx_rt_generic INTO DATA(lo_generic_ex).
        lv_error = |Setup failed: { lo_generic_ex->if_message~get_text( ) }|.
        " Try to clean up
        TRY.
            IF av_bucket_name IS NOT INITIAL.
              /awsex/cl_utils=>cleanup_bucket( iv_bucket = av_bucket_name io_s3 = ao_s3 ).
            ENDIF.
          CATCH /aws1/cx_rt_generic.
            " Ignore cleanup errors
        ENDTRY.
        cl_abap_unit_assert=>fail( msg = lv_error ).
    ENDTRY.
  ENDMETHOD.

  METHOD class_teardown.
    " Note: CloudFront distributions take a long time to delete (15-30 minutes)
    " We will NOT delete the distribution but it is tagged with 'convert_test'
    " for manual cleanup by the user.

    MESSAGE 'CloudFront distribution cleanup skipped - tagged for manual deletion.' TYPE 'I'.
    MESSAGE 'Tagged resources with convert_test=true:' TYPE 'I'.
    IF av_distribution_id IS NOT INITIAL.
      MESSAGE '- Distribution ID: ' && av_distribution_id TYPE 'I'.
    ENDIF.
    IF av_bucket_name IS NOT INITIAL.
      MESSAGE '- S3 Bucket: ' && av_bucket_name && ' (will NOT be deleted due to CloudFront dependency)' TYPE 'I'.
    ENDIF.
    IF av_oac_id IS NOT INITIAL.
      MESSAGE '- Origin Access Control: ' && av_oac_id && ' (will NOT be deleted due to CloudFront dependency)' TYPE 'I'.
    ENDIF.
    MESSAGE 'Please manually delete these resources after disabling the distribution.' TYPE 'I'.

    " Do not clean up resources - they are tagged for manual cleanup
    " Uncomment the following to enable cleanup (not recommended for CI/CD)
    " IF av_distribution_id IS NOT INITIAL.
    "   TRY.
    "     " Disable and delete distribution
    "     DATA(lo_config) = ao_fnt->getdistributionconfig( iv_id = av_distribution_id ).
    "     DATA(lo_dist_config) = lo_config->get_distributionconfig( ).
    "     lo_dist_config->set_enabled( abap_false ).
    "     ao_fnt->updatedistribution(
    "       iv_id = av_distribution_id
    "       io_distributionconfig = lo_dist_config
    "       iv_ifmatch = lo_config->get_etag( ) ).
    "     " Wait and delete...
    "   CATCH /aws1/cx_rt_generic.
    "   ENDTRY.
    " ENDIF.
  ENDMETHOD.

  METHOD list_distributions.
    " Test list_distributions method
    DATA(lo_result) = ao_fnt_actions->list_distributions( iv_max_items = 10 ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'ListDistributions returned no result' ).

    DATA(lo_distribution_list) = lo_result->get_distributionlist( ).
    cl_abap_unit_assert=>assert_bound(
      act = lo_distribution_list
      msg = 'Distribution list is not bound' ).

    DATA(lv_quantity) = lo_distribution_list->get_quantity( ).
    cl_abap_unit_assert=>assert_differs(
      act = lv_quantity
      exp = 0
      msg = 'No distributions found in list' ).

    " Verify the distribution items are present
    DATA(lt_items) = lo_distribution_list->get_items( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_items
      msg = 'Distribution items list is empty' ).

    " Verify our test distribution is in the list
    DATA lv_found TYPE abap_bool VALUE abap_false.
    LOOP AT lt_items INTO DATA(lo_distribution_summary).
      DATA(lv_dist_id) = lo_distribution_summary->get_id( ).
      IF lv_dist_id = av_distribution_id.
        lv_found = abap_true.
        " Verify required fields
        DATA(lv_domain_name) = lo_distribution_summary->get_domainname( ).
        cl_abap_unit_assert=>assert_not_initial(
          act = lv_domain_name
          msg = 'Distribution domain name is empty' ).
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
      act = lv_found
      msg = |Test distribution { av_distribution_id } not found in list| ).
  ENDMETHOD.

  METHOD update_distribution.
    " Test update_distribution method
    " Create a unique test comment
    DATA lv_timestamp TYPE timestamp.
    GET TIME STAMP FIELD lv_timestamp.
    DATA(lv_test_comment) = |Test comment updated at { lv_timestamp }|.

    " Get current ETag before update
    DATA(lo_config_result) = ao_fnt->getdistributionconfig( iv_id = av_distribution_id ).
    DATA(lv_current_etag) = lo_config_result->get_etag( ).

    " Update the distribution using the action method
    DATA(lo_result) = ao_fnt_actions->update_distribution(
      iv_distribution_id = av_distribution_id
      iv_comment = lv_test_comment
      iv_if_match = lv_current_etag
    ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'UpdateDistribution returned no result' ).

    " Verify the comment was updated by retrieving the distribution
    DATA(lo_verify_result) = ao_fnt->getdistributionconfig( iv_id = av_distribution_id ).
    DATA(lo_verify_config) = lo_verify_result->get_distributionconfig( ).
    DATA(lv_updated_comment) = lo_verify_config->get_comment( ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_updated_comment
      exp = lv_test_comment
      msg = 'Distribution comment was not updated correctly' ).

    " Restore original comment for cleanup
    lo_verify_config->set_comment( av_original_comment ).
    ao_fnt->updatedistribution(
      iv_id = av_distribution_id
      io_distributionconfig = lo_verify_config
      iv_ifmatch = lo_verify_result->get_etag( ) ).
  ENDMETHOD.

ENDCLASS.
