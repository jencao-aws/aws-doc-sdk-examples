" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS /awsex/cl_sup_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS describe_services
      IMPORTING
                !iv_language     TYPE /aws1/suplanguage
      EXPORTING
                !ot_services     TYPE /aws1/cl_supservice=>tt_servicelist
      RAISING   /aws1/cx_rt_generic.

    METHODS describe_severity_levels
      IMPORTING
                !iv_language           TYPE /aws1/suplanguage
      EXPORTING
                !ot_severity_levels    TYPE /aws1/cl_supseveritylevel=>tt_severitylevelslist
      RAISING   /aws1/cx_rt_generic.

    METHODS create_case
      IMPORTING
                !iv_subject            TYPE /aws1/supsubject
                !iv_service_code       TYPE /aws1/supservicecode2
                !iv_severity_code      TYPE /aws1/supseveritycode
                !iv_category_code      TYPE /aws1/supcategorycode
                !iv_communication_body TYPE /aws1/supcommunicationbody
                !iv_language           TYPE /aws1/suplanguage
                !iv_issue_type         TYPE /aws1/supissuetype
      EXPORTING
                !ov_case_id            TYPE /aws1/supcaseid
      RAISING   /aws1/cx_rt_generic.

    METHODS add_attachment_to_set
      EXPORTING
                !ov_attachment_set_id TYPE /aws1/supattachmentsetid
      RAISING   /aws1/cx_rt_generic.

    METHODS add_communication_to_case
      IMPORTING
                !iv_attachment_set_id TYPE /aws1/supattachmentsetid
                !iv_case_id           TYPE /aws1/supcaseid
      RAISING   /aws1/cx_rt_generic.

    METHODS describe_communications
      IMPORTING
                !iv_case_id           TYPE /aws1/supcaseid
      EXPORTING
                !ot_communications    TYPE /aws1/cl_supcommunication=>tt_communicationlist
      RAISING   /aws1/cx_rt_generic.

    METHODS describe_attachment
      IMPORTING
                !iv_attachment_id TYPE /aws1/supattachmentid
      EXPORTING
                !ov_file_name     TYPE /aws1/supfilename
      RAISING   /aws1/cx_rt_generic.

    METHODS resolve_case
      IMPORTING
                !iv_case_id       TYPE /aws1/supcaseid
      EXPORTING
                !ov_final_status  TYPE /aws1/supcasestatus
      RAISING   /aws1/cx_rt_generic.

    METHODS describe_cases
      IMPORTING
                !iv_after_time    TYPE /aws1/supaftertime
                !iv_before_time   TYPE /aws1/supbeforetime
                !iv_resolved      TYPE /aws1/supincluderesolvedcases
      EXPORTING
                !ot_cases         TYPE /aws1/cl_supcasedetails=>tt_caselist
      RAISING   /aws1/cx_rt_generic.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /AWSEX/CL_SUP_ACTIONS IMPLEMENTATION.


  METHOD describe_services.

    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_sup) = /aws1/cl_sup_factory=>create( lo_session ).

    " snippet-start:[sup.abapv1.describe_services]
    TRY.
        " iv_language example: 'en'
        DATA(lo_result) = lo_sup->describeservices( iv_language = iv_language ).
        ot_services = lo_result->get_services( ).
        MESSAGE 'Retrieved AWS Support services.' TYPE 'I'.
      CATCH /aws1/cx_supinternalservererr.
        MESSAGE 'An internal server error occurred.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[sup.abapv1.describe_services]

  ENDMETHOD.


  METHOD describe_severity_levels.

    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_sup) = /aws1/cl_sup_factory=>create( lo_session ).

    " snippet-start:[sup.abapv1.describe_severity_levels]
    TRY.
        " iv_language example: 'en'
        DATA(lo_result) = lo_sup->describeseveritylevels( iv_language = iv_language ).
        ot_severity_levels = lo_result->get_severitylevels( ).
        MESSAGE 'Retrieved severity levels for AWS Support.' TYPE 'I'.
      CATCH /aws1/cx_supinternalservererr.
        MESSAGE 'An internal server error occurred.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[sup.abapv1.describe_severity_levels]

  ENDMETHOD.


  METHOD create_case.

    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_sup) = /aws1/cl_sup_factory=>create( lo_session ).

    " snippet-start:[sup.abapv1.create_case]
    TRY.
        " iv_subject example: 'Example case for testing, ignore.'
        " iv_service_code example: 'amazon-dynamodb'
        " iv_severity_code example: 'low'
        " iv_category_code example: 'general-question'
        " iv_communication_body example: 'Example support case body.'
        " iv_language example: 'en'
        " iv_issue_type example: 'customer-service'
        DATA(lo_result) = lo_sup->createcase(
          iv_subject = iv_subject
          iv_servicecode = iv_service_code
          iv_severitycode = iv_severity_code
          iv_categorycode = iv_category_code
          iv_communicationbody = iv_communication_body
          iv_language = iv_language
          iv_issuetype = iv_issue_type ).
        ov_case_id = lo_result->get_caseid( ).
        MESSAGE 'AWS Support case created successfully.' TYPE 'I'.
      CATCH /aws1/cx_supcasecreationlmte00.
        MESSAGE 'Case creation limit exceeded.' TYPE 'E'.
      CATCH /aws1/cx_supattachmentsetexp00.
        MESSAGE 'Attachment set expired.' TYPE 'E'.
      CATCH /aws1/cx_supattachmentsetidn00.
        MESSAGE 'Attachment set ID not found.' TYPE 'E'.
      CATCH /aws1/cx_supinternalservererr.
        MESSAGE 'An internal server error occurred.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[sup.abapv1.create_case]

  ENDMETHOD.


  METHOD add_attachment_to_set.

    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_sup) = /aws1/cl_sup_factory=>create( lo_session ).

    " snippet-start:[sup.abapv1.add_attachments_to_set]
    TRY.
        DATA lt_attachments TYPE /aws1/cl_supattachment=>tt_attachments.
        DATA lv_data TYPE /aws1/supdata.
        DATA lv_string TYPE string.

        " Example content for attachment
        lv_string = 'This is a sample file for attachment to a support case.'.
        " Convert string to base64 encoded xstring
        lv_data = cl_http_utility=>encode_base64( unencoded = lv_string ).

        DATA(lo_attachment) = NEW /aws1/cl_supattachment(
          iv_filename = 'attachment_file.txt'
          iv_data = lv_data ).
        APPEND lo_attachment TO lt_attachments.

        DATA(lo_result) = lo_sup->addattachmentstoset( it_attachments = lt_attachments ).
        ov_attachment_set_id = lo_result->get_attachmentsetid( ).
        MESSAGE 'Attachment set created successfully.' TYPE 'I'.
      CATCH /aws1/cx_supattachmentlmtexcd.
        MESSAGE 'Attachment limit exceeded.' TYPE 'E'.
      CATCH /aws1/cx_supattachmentsetexp00.
        MESSAGE 'Attachment set expired.' TYPE 'E'.
      CATCH /aws1/cx_supattachmentsetidn00.
        MESSAGE 'Attachment set ID not found.' TYPE 'E'.
      CATCH /aws1/cx_supattachmentsetsiz00.
        MESSAGE 'Attachment set size limit exceeded.' TYPE 'E'.
      CATCH /aws1/cx_supinternalservererr.
        MESSAGE 'An internal server error occurred.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[sup.abapv1.add_attachments_to_set]

  ENDMETHOD.


  METHOD add_communication_to_case.

    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_sup) = /aws1/cl_sup_factory=>create( lo_session ).

    " snippet-start:[sup.abapv1.add_communication_to_case]
    TRY.
        " iv_case_id example: 'case-12345678910-2013-c4c1d2bf33c5cf47'
        " iv_attachment_set_id example: 'as-2f5a6faa2a4a1e600-mu-nk5xQlBr70-G1cUos5LZkd38KOAHZa9BMDVzNEXAMPLE'
        lo_sup->addcommunicationtocase(
          iv_caseid = iv_case_id
          iv_communicationbody = 'This is an example communication added to a support case.'
          iv_attachmentsetid = iv_attachment_set_id ).
        MESSAGE 'Communication added to support case successfully.' TYPE 'I'.
      CATCH /aws1/cx_supcaseidnotfound.
        MESSAGE 'Case ID not found.' TYPE 'E'.
      CATCH /aws1/cx_supattachmentsetexp00.
        MESSAGE 'Attachment set expired.' TYPE 'E'.
      CATCH /aws1/cx_supattachmentsetidn00.
        MESSAGE 'Attachment set ID not found.' TYPE 'E'.
      CATCH /aws1/cx_supinternalservererr.
        MESSAGE 'An internal server error occurred.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[sup.abapv1.add_communication_to_case]

  ENDMETHOD.


  METHOD describe_communications.

    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_sup) = /aws1/cl_sup_factory=>create( lo_session ).

    " snippet-start:[sup.abapv1.describe_communications]
    TRY.
        DATA lv_nexttoken TYPE /aws1/supnexttoken.
        DATA lt_all_communications TYPE /aws1/cl_supcommunication=>tt_communicationlist.

        " Use paginator to retrieve all communications
        " iv_case_id example: 'case-12345678910-2013-c4c1d2bf33c5cf47'
        DO.
          DATA(lo_result) = lo_sup->describecommunications(
            iv_caseid = iv_case_id
            iv_nexttoken = lv_nexttoken ).

          DATA(lt_communications) = lo_result->get_communications( ).
          APPEND LINES OF lt_communications TO lt_all_communications.

          lv_nexttoken = lo_result->get_nexttoken( ).
          IF lv_nexttoken IS INITIAL.
            EXIT.
          ENDIF.
        ENDDO.

        ot_communications = lt_all_communications.
        MESSAGE 'Retrieved communications for support case.' TYPE 'I'.
      CATCH /aws1/cx_supcaseidnotfound.
        MESSAGE 'Case ID not found.' TYPE 'E'.
      CATCH /aws1/cx_supinternalservererr.
        MESSAGE 'An internal server error occurred.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[sup.abapv1.describe_communications]

  ENDMETHOD.


  METHOD describe_attachment.

    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_sup) = /aws1/cl_sup_factory=>create( lo_session ).

    " snippet-start:[sup.abapv1.describe_attachment]
    TRY.
        " iv_attachment_id example: 'attachment-1234567890-abcd-efgh-ijkl-1234567890ab'
        DATA(lo_result) = lo_sup->describeattachment( iv_attachmentid = iv_attachment_id ).
        DATA(lo_attachment) = lo_result->get_attachment( ).
        ov_file_name = lo_attachment->get_filename( ).
        MESSAGE 'Retrieved attachment information.' TYPE 'I'.
      CATCH /aws1/cx_supattachmentidnotfnd.
        MESSAGE 'Attachment ID not found.' TYPE 'E'.
      CATCH /aws1/cx_supdscattachmentlmt00.
        MESSAGE 'Describe attachment limit exceeded.' TYPE 'E'.
      CATCH /aws1/cx_supinternalservererr.
        MESSAGE 'An internal server error occurred.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[sup.abapv1.describe_attachment]

  ENDMETHOD.


  METHOD resolve_case.

    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_sup) = /aws1/cl_sup_factory=>create( lo_session ).

    " snippet-start:[sup.abapv1.resolve_case]
    TRY.
        " iv_case_id example: 'case-12345678910-2013-c4c1d2bf33c5cf47'
        DATA(lo_result) = lo_sup->resolvecase( iv_caseid = iv_case_id ).
        ov_final_status = lo_result->get_finalcasestatus( ).
        MESSAGE 'Support case resolved successfully.' TYPE 'I'.
      CATCH /aws1/cx_supcaseidnotfound.
        MESSAGE 'Case ID not found.' TYPE 'E'.
      CATCH /aws1/cx_supinternalservererr.
        MESSAGE 'An internal server error occurred.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[sup.abapv1.resolve_case]

  ENDMETHOD.


  METHOD describe_cases.

    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_sup) = /aws1/cl_sup_factory=>create( lo_session ).

    " snippet-start:[sup.abapv1.describe_cases]
    TRY.
        DATA lv_nexttoken TYPE /aws1/supnexttoken.
        DATA lt_all_cases TYPE /aws1/cl_supcasedetails=>tt_caselist.

        " Use paginator to retrieve all cases
        " iv_after_time example: '2023-01-01T00:00:00Z'
        " iv_before_time example: '2023-12-31T23:59:59Z'
        " iv_resolved example: abap_true for resolved cases, abap_false for open cases
        DO.
          DATA(lo_result) = lo_sup->describecases(
            iv_aftertime = iv_after_time
            iv_beforetime = iv_before_time
            iv_includeresolvedcases = iv_resolved
            iv_language = 'en'
            iv_nexttoken = lv_nexttoken ).

          DATA(lt_cases) = lo_result->get_cases( ).
          APPEND LINES OF lt_cases TO lt_all_cases.

          lv_nexttoken = lo_result->get_nexttoken( ).
          IF lv_nexttoken IS INITIAL.
            EXIT.
          ENDIF.
        ENDDO.

        " Filter for resolved cases if requested
        IF iv_resolved = abap_true.
          DELETE lt_all_cases WHERE table_line->get_status( ) <> 'resolved'.
        ENDIF.

        ot_cases = lt_all_cases.
        MESSAGE 'Retrieved support cases.' TYPE 'I'.
      CATCH /aws1/cx_supcaseidnotfound.
        MESSAGE 'Case ID not found.' TYPE 'E'.
      CATCH /aws1/cx_supinternalservererr.
        MESSAGE 'An internal server error occurred.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[sup.abapv1.describe_cases]

  ENDMETHOD.
ENDCLASS.
