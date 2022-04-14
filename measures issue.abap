*&---------------------------------------------------------------------*
*& Report  UJA_MAINTAIN_MEASURE_FORMULA
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*
"kal070915 2203945 - Enhance the validation for modifying pre-deliver measure formula
REPORT  uja_maintain_measure_formula.

TYPE-POOLS: uja00.

TABLES: uja_s_formula_gui.

*&---------------------------------------------------------------------*
*&       Class LCL_HANDLER
*&---------------------------------------------------------------------*
*        Text
*----------------------------------------------------------------------*
CLASS lcl_handler DEFINITION FINAL.
  PUBLIC SECTION.

    METHODS handler_double_click
      FOR EVENT double_click OF cl_gui_alv_grid
        IMPORTING
          es_row_no .
ENDCLASS.               "LCL_HANDLER

TYPES:
  BEGIN OF s_dim_option,
*    seqnr     TYPE uj_seqnr,
  dimension  TYPE uj_dim_name,
  if_basemember TYPE uj_flg,
  if_pmember TYPE uj_flg,
  if_allmember TYPE uj_flg,
  if_axis     TYPE uj_flg,
  members TYPE string,
END OF s_dim_option.
TYPES:
  t_dim_option TYPE  TABLE OF s_dim_option .

DATA:   gt_formula_app TYPE STANDARD TABLE OF uja_formula_app,
        gt_formula_alv LIKE gt_formula_app,
        gs_formula_alv LIKE LINE OF gt_formula_app,
        go_alv_grid    TYPE REF TO cl_gui_alv_grid,
        go_container_alv TYPE REF TO cl_gui_custom_container,
        go_container_editor TYPE REF TO cl_gui_custom_container,
        go_editor      TYPE REF TO cl_gui_textedit,
        gd_dynnr       TYPE sy-dynnr VALUE '1999',
        gd_storage_type TYPE uja_formula_app-storage_type,
        gf_display     TYPE uj_flg,
        go_handler     TYPE REF TO lcl_handler,
        ok_code        TYPE sy-ucomm,
"        save_ok        type sy-ucomm,
        pre_action        TYPE sy-ucomm,
        g_index TYPE int4,
        gv_tmp type string, " note 1831329 Yanlin@2013-3-7
        gd_formula_stat TYPE string. " formula_stat,input



PARAMETERS: p_appset TYPE uja_formula_app-appset_id OBLIGATORY,
            p_appl   TYPE uja_formula_app-application_id OBLIGATORY.
data p_user   TYPE uje_user-user_id. " note 1831329 remove user Yanlin@2013-3-7
p_user = sy-uname.

START-OF-SELECTION.

  PERFORM execute_query.

END-OF-SELECTION.

"Begin,added to record user activity, May 20th 2016,CHENHAIF, Note 2304971
cl_uja_actvty_mgr=>record_logon_activity(
  exporting
  i_appset_id = ''
  i_activity  = cl_uja_actvty_mgr=>gc_act_report_uja_maint_meas_f ).
"End,added to record user activity, May 20th 2016,CHENHAIF, Note 2304971

  IF gt_formula_app IS NOT INITIAL.
    CALL SCREEN 2000.
  ENDIF.
*&---------------------------------------------------------------------*
*&      Module  STATUS_2000  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE status_2000 OUTPUT.
  SET PF-STATUS 'STATUS'.
  SET TITLEBAR 'TITLE'.

ENDMODULE.                 " STATUS_2000  OUTPUT
*&---------------------------------------------------------------------*
*&      Form  EXECUTE_QUERY
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM execute_query .

  DATA: ld_storage_type TYPE uja_formula_app-storage_type,
        lx_static TYPE REF TO cx_uj_static_check.

  DATA:
        lt_formula_app TYPE STANDARD TABLE OF uja_formula_app,
        ls_formula_app TYPE uja_formula_app,
        lt_user TYPE STANDARD TABLE OF uje_user.            "#EC NEEDED
  FIELD-SYMBOLS:
  <ls_formula>     TYPE uja_formula_app.


* Get the storage type for the application
* using this API.
  DATA: ls_appl_info TYPE  uja_s_api_appl_info.
  DATA: ls_user TYPE uj0_s_user.

*Check this user.

* begin note 1831329 Yanlin@2013-3-7
*  CONDENSE   p_user.
*  IF p_user IS INITIAL.
*    MESSAGE e305(uja_exception) .
*    RETURN.
*  ELSE.
*    TRY .
*        cl_uja_security_checker=>check_get_access(
*          i_appset_id = p_appset
*          i_obj_type = cl_uja_security_checker=>gc_obj_type_appset
*          i_user_id = p_user
*        ).
*      CATCH cx_uj_no_auth cx_uj_static_check.
*        MESSAGE i310(uja_exception) WITH p_user p_appset.
*        CLEAR gt_formula_app.
*        RETURN.
*    ENDTRY.
*  ENDIF.
*
  ls_user-user_id = p_user.
* end note 1831329
*----------------------------------------

  " New API replaces the RFC Function Module "AHOU 28.04.2010
  DATA  lo_application TYPE REF TO if_uja_application_manager.
  DATA  ls_application TYPE uja_s_application.

  TRY .
      lo_application = cl_uja_bpc_admin_factory=>get_application_manager(
        i_appset_id = p_appset
        i_application_id  = p_appl
      ).

      lo_application->get(
        IMPORTING
          es_application = ls_application ).
    CATCH cx_uj_static_check INTO lx_static.
      MESSAGE ID lx_static->if_t100_message~t100key-msgid TYPE 'E' NUMBER lx_static->if_t100_message~t100key-msgno
        WITH lx_static->if_t100_message~t100key-attr1 lx_static->if_t100_message~t100key-attr2 lx_static->if_t100_message~t100key-attr3 lx_static->if_t100_message~t100key-attr4.
      CLEAR gt_formula_app.
      RETURN.
  ENDTRY.

  IF ls_application-storage_type IS NOT INITIAL.
    ld_storage_type = ls_application-storage_type.
  ELSE.
    ld_storage_type = uja00_cs_storage_type-period.
  ENDIF.
*----------------------------------------

  SELECT appset_id application_id formula_name
  storage_type formula_type formula_stat solve_order description
  INTO CORRESPONDING FIELDS OF TABLE gt_formula_app
  FROM uja_formula_app

  WHERE appset_id = p_appset
  AND application_id = p_appl
  AND storage_type = ld_storage_type.
  gd_storage_type =  ld_storage_type.

  LOOP AT gt_formula_app ASSIGNING <ls_formula>.
    IF <ls_formula>-description IS INITIAL.
      SELECT description INTO CORRESPONDING FIELDS OF TABLE lt_formula_app
      FROM uja_formula WHERE
      storage_type =  <ls_formula>-storage_type
      AND formula_name =  <ls_formula>-formula_name.
      IF sy-subrc = 0.
        READ TABLE lt_formula_app INTO ls_formula_app  INDEX 1. "#EC CI_NOORDER
        <ls_formula>-description = ls_formula_app-description.
      ENDIF.
    ENDIF.
  ENDLOOP."Elw

  gt_formula_alv = gt_formula_app.

ENDFORM.                    " EXECUTE_QUERY
*&---------------------------------------------------------------------*
*&      Module  PBO_2000  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE pbo_2000 OUTPUT.
  PERFORM pbo_2000.
ENDMODULE.                 " PBO_2000  OUTPUT
*&---------------------------------------------------------------------*
*&      Form  PBO_2000
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM pbo_2000 .

  DATA: lt_exclude TYPE ui_functions.
  DATA: ls_exclude TYPE ui_func.
  DATA: lt_fieldcat TYPE lvc_t_fcat.
  DATA: ls_fieldcat TYPE lvc_s_fcat.

  DATA: ls_layout  TYPE lvc_s_layo.
  DATA lt_rows TYPE lvc_t_row.
  DATA ls_row TYPE lvc_s_row.
* Create Controls
  IF go_container_alv IS INITIAL.
    CREATE OBJECT go_container_alv
      EXPORTING
        container_name = 'CONTAINER_ALV'.

* Create control based ALV grid
    CREATE OBJECT go_alv_grid
      EXPORTING
        i_parent      = go_container_alv
        i_appl_events = abap_true.


* Set Field Cat
    REFRESH lt_fieldcat.
    CLEAR ls_fieldcat .
*    ls_fieldcat-reptext    = 'AppSet'. "#EC NOTEXT
    ls_fieldcat-fieldname  = 'APPSET_ID'.
    ls_fieldcat-rollname   = 'UJ_APPSET_ID'.
    ls_fieldcat-outputlen  = '20'.
    APPEND ls_fieldcat  TO lt_fieldcat.


    CLEAR ls_fieldcat .
*    ls_fieldcat-reptext    = 'Application'. "#EC NOTEXT
    ls_fieldcat-fieldname  = 'APPLICATION_ID'.
    ls_fieldcat-rollname   = 'UJ_APPL_ID'.
    ls_fieldcat-outputlen  = '20'.
    APPEND ls_fieldcat  TO lt_fieldcat.

    CLEAR ls_fieldcat .
*    ls_fieldcat-reptext    = 'Store type'. "#EC NOTEXT
    ls_fieldcat-fieldname  = 'STORAGE_TYPE'.
    ls_fieldcat-rollname   = 'UJ_STORAGE_TYPE'.
    ls_fieldcat-outputlen  = '10'.
    APPEND ls_fieldcat  TO lt_fieldcat.

    CLEAR ls_fieldcat .
*    ls_fieldcat-reptext    = 'Formula Name'. "#EC NOTEXT
    ls_fieldcat-fieldname  = 'FORMULA_NAME'.
    ls_fieldcat-rollname   = 'UJ_FORMULA_NAME'.
    ls_fieldcat-outputlen  = '20'.

    APPEND ls_fieldcat  TO lt_fieldcat.
    CLEAR ls_fieldcat .
*    ls_fieldcat-reptext    =  'Description'. "#EC NOTEXT
    ls_fieldcat-fieldname  = 'DESCRIPTION'.
    ls_fieldcat-rollname   = 'UJ_DESC'.
    ls_fieldcat-outputlen  = '30'.
    APPEND ls_fieldcat  TO lt_fieldcat.

* Set selection mode to "B"  --  Single Line"elw
    ls_layout-sel_mode = 'B'.

* Exclude all buttons
    REFRESH lt_exclude.
    ls_exclude = '&EXCLALLFC'.
    APPEND ls_exclude TO lt_exclude.

* create event handler
    CREATE OBJECT go_handler.

    SET HANDLER go_handler->handler_double_click FOR go_alv_grid.

* set for first display
    go_alv_grid->set_table_for_first_display(
    EXPORTING
      is_layout            = ls_layout
      it_toolbar_excluding = lt_exclude
    CHANGING
      it_outtab            = gt_formula_alv
      it_fieldcatalog      = lt_fieldcat ).

  ELSE.
    go_alv_grid->refresh_table_display( ).

    IF g_index IS INITIAL.
      g_index = 1.
    ENDIF.

    ls_row-index = g_index.
    APPEND ls_row TO lt_rows.

    CALL METHOD go_alv_grid->set_selected_rows
      EXPORTING
        it_index_rows = lt_rows.

  ENDIF.


ENDFORM.                                                    " PBO_2000
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_2000  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_2000 INPUT.
  PERFORM user_command_2000.
ENDMODULE.                 " USER_COMMAND_2000  INPUT
*&---------------------------------------------------------------------*
*&      Form  USER_COMMAND_2000
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM user_command_2000 .
  DATA :

"        ls_selected_row type lvc_s_roid ,
        lf_sys TYPE uj_flg," system formula,check uja_formula
        lt_cell TYPE lvc_t_cell,
        ls_cell LIKE LINE OF lt_cell,
        lt_formula_app TYPE STANDARD TABLE OF uja_formula_app,"ELW
        ls_formula_app TYPE uja_formula_app,
        l_success TYPE uj_flg,
        l_message TYPE string,
        lt_message type uj0_t_message,
        ls_message like line of lt_message,
        l_answer TYPE c,
        ld_formula_stat TYPE string.

"  cl_gui_cfw=>flush( ) . " note 1831329 enhance user interaction Yanlin@2013-3-8

  CLEAR lt_formula_app.
  CLEAR ls_formula_app.
  CLEAR l_success.
  CLEAR l_message."END

  ok_code = sy-ucomm.
  CLEAR  lf_sys.
  "clear lt_selected_rows.
  CASE ok_code.
    WHEN 'BACK' OR 'EXIT'.
      CLEAR ok_code.
      CLEAR pre_action.
      LEAVE TO SCREEN 0.

    WHEN 'CREATE'.
      CLEAR uja_s_formula_gui.
      uja_s_formula_gui-appset_id = p_appset.
      uja_s_formula_gui-application_id = p_appl.
      CLEAR gs_formula_alv. "elw no selection.
      CLEAR gd_formula_stat.

      pre_action = ok_code.
      gd_dynnr = '2100'.
      gf_display = space."elw
      "leave to screen 4000.


    WHEN 'DELETE' OR 'CHANGE' OR 'DISPLAY'.

      CALL METHOD go_alv_grid->get_selected_cells
        IMPORTING
          et_cell = lt_cell.

      READ TABLE lt_cell INTO ls_cell INDEX 1.
      g_index = ls_cell-row_id.
      READ TABLE gt_formula_alv INDEX ls_cell-row_id INTO gs_formula_alv.
      gd_formula_stat = gs_formula_alv-formula_stat.


      CASE ok_code.
        WHEN 'DELETE'.
          PERFORM check_sys_formula CHANGING lf_sys.

          IF lf_sys EQ abap_true.
            MESSAGE e301(uja_exception) .
            RETURN.
          ELSE.
            l_message = text-002.
            REPLACE   '&1' IN l_message  WITH  gs_formula_alv-formula_name .

            CALL FUNCTION 'POPUP_TO_CONFIRM'
              EXPORTING
*               TITLEBAR                    = ' '
*               DIAGNOSE_OBJECT             = ' '
                text_question               = l_message
*               TEXT_BUTTON_1               = 'Ja'(001)
*               ICON_BUTTON_1               = ' '
*               TEXT_BUTTON_2               = 'Nein'(002)
*               ICON_BUTTON_2               = ' '
*               DEFAULT_BUTTON              = '1'
*               DISPLAY_CANCEL_BUTTON       = 'X'
*               USERDEFINED_F1_HELP         = ' '
*               START_COLUMN                = 25
*               START_ROW                   = 6
*               POPUP_TYPE                  =
*               IV_QUICKINFO_BUTTON_1       = ' '
*               IV_QUICKINFO_BUTTON_2       = ' '
             IMPORTING
               answer                      = l_answer
*             TABLES
*               PARAMETER                   =
*             EXCEPTIONS
*               TEXT_NOT_FOUND              = 1
*               OTHERS                      = 2
                      .
*            if sy-subrc <> 0.
*              message id sy-msgid type sy-msgty number sy-msgno
*                      with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
*            endif.


            IF l_answer EQ '1'.
              DELETE FROM uja_formula_app  WHERE appset_id = gs_formula_alv-appset_id
              AND application_id = gs_formula_alv-application_id AND formula_name = gs_formula_alv-formula_name AND
              storage_type = gs_formula_alv-storage_type.

              DELETE gt_formula_alv INDEX ls_cell-row_id.
              "delete gt_formula_app from gs_formula_alv.

            ENDIF.
          ENDIF.
          PERFORM initial.
          MESSAGE s307(uja_exception) .



        WHEN 'CHANGE'.
          PERFORM check_sys_formula CHANGING lf_sys.
          IF lf_sys EQ abap_true.
            IF ( gs_formula_alv-formula_name = uja00_cs_measure_member-per AND
                gs_formula_alv-storage_type = uja00_cs_storage_type-period )
               OR ( gs_formula_alv-formula_name = uja00_cs_measure_member-ytd AND
                gs_formula_alv-storage_type = uja00_cs_storage_type-ytd ).
              "message e302(uja_exception) .
              "For currently Kiven lock uja_exception,I use text-004 temporay
              l_message = text-004.
              REPLACE '&1' IN l_message WITH    gs_formula_alv-formula_name.
              REPLACE '&2' IN l_message WITH    gs_formula_alv-storage_type .
              MESSAGE l_message TYPE 'E' .
              RETURN.
            ENDIF.
          ENDIF.
          l_message = text-003.
          REPLACE   '&1' IN l_message  WITH  gs_formula_alv-formula_name .

          CALL FUNCTION 'POPUP_TO_CONFIRM'
            EXPORTING
*               TITLEBAR                    = ' '
*               DIAGNOSE_OBJECT             = ' '
              text_question               = l_message
*               TEXT_BUTTON_1               = 'Ja'(001)
*               ICON_BUTTON_1               = ' '
*               TEXT_BUTTON_2               = 'Nein'(002)
*               ICON_BUTTON_2               = ' '
*               DEFAULT_BUTTON              = '1'
*               DISPLAY_CANCEL_BUTTON       = 'X'
*               USERDEFINED_F1_HELP         = ' '
*               START_COLUMN                = 25
*               START_ROW                   = 6
*               POPUP_TYPE                  =
*               IV_QUICKINFO_BUTTON_1       = ' '
*               IV_QUICKINFO_BUTTON_2       = ' '
           IMPORTING
             answer                      = l_answer
*             TABLES
*               PARAMETER                   =
*             EXCEPTIONS
*               TEXT_NOT_FOUND              = 1
*               OTHERS                      = 2
                    .
*            if sy-subrc <> 0.
*              message id sy-msgid type sy-msgty number sy-msgno
*                      with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
*            endif.

          IF l_answer EQ '1'.
            MOVE-CORRESPONDING gs_formula_alv TO uja_s_formula_gui.
            pre_action = ok_code.
            gd_dynnr = '2100'.
            gf_display = space.
          ELSE.
            gd_dynnr = '1999'.
            gf_display = abap_true.
            RETURN.
          ENDIF.

        WHEN 'DISPLAY'.
          MOVE-CORRESPONDING gs_formula_alv TO uja_s_formula_gui.
          gd_dynnr = '2100'.
          gf_display = 'X'.
      ENDCASE.

    WHEN 'SAVE'.
      IF gd_dynnr EQ '2100' AND  gf_display EQ space.
"        cl_gui_cfw=>flush( ) . " note 1831329 enhance user interaction Yanlin@2013-3-8
        " validaton when saving
        IF p_user IS INITIAL.
          MESSAGE i305(uja_exception) .
          RETURN.
        ENDIF.

        perform get_formula_stat. " note 1831329 enhance user interaction Yanlin@2013-3-7

        CONDENSE uja_s_formula_gui-formula_name.
        ld_formula_stat = gd_formula_stat.
*        condense gd_formula_stat.
        CONDENSE ld_formula_stat.
        IF uja_s_formula_gui-formula_name IS INITIAL.
          MESSAGE i308(uja_exception) .
          RETURN.
        ENDIF.

        IF  ld_formula_stat IS INITIAL.
          MESSAGE i309(uja_exception) .
          RETURN.
        ENDIF.

        CASE pre_action.
          WHEN 'CREATE'.
            SELECT * FROM uja_formula_app INTO CORRESPONDING FIELDS OF TABLE lt_formula_app
              WHERE appset_id = p_appset
              AND application_id = p_appl
              AND formula_name = uja_s_formula_gui-formula_name
              AND storage_type = gd_storage_type.
            IF sy-subrc = 0.
              MESSAGE i303(uja_exception) .
              RETURN.
            ELSE.
              ls_formula_app-appset_id = p_appset.
              ls_formula_app-application_id = p_appl.
              ls_formula_app-formula_name = uja_s_formula_gui-formula_name.
              ls_formula_app-storage_type = gd_storage_type.
              ls_formula_app-solve_order = 3.
              ls_formula_app-formula_stat =  gd_formula_stat.
              ls_formula_app-formula_type = 'FIN'.
              ls_formula_app-description = uja_s_formula_gui-description.
              INSERT ls_formula_app INTO TABLE lt_formula_app.
              INSERT uja_formula_app FROM TABLE lt_formula_app.
            ENDIF.

            PERFORM validation CHANGING l_success l_message lt_message.

            IF l_success EQ abap_true.

              APPEND ls_formula_app TO gt_formula_alv.
              "gs_formula_alv = ls_formula_app.

              PERFORM initial.
              MESSAGE i306(uja_exception) .

              "ls_formulas-formula_name = uja_s_formula_gui-formula_name.
              "ls_formulas-formula_stat = scrn-formula_stat.
              "leave to screen 2000.
            ELSE.
              DELETE FROM uja_formula_app
                WHERE appset_id = p_appset
                AND application_id = p_appl
                AND formula_name = ls_formula_app-formula_name
                AND storage_type = gd_storage_type.
              "SAZ20110808 1618458 begin
              if l_message is not initial.
                MESSAGE l_message TYPE 'I'.
              endif.
              "SAZ20110808 1618458 end
              if lt_message is not initial.
                loop at lt_message into ls_message.
                  message id ls_message-msgid type ls_message-msgty number ls_message-msgno
                  with ls_message-msgv1 ls_message-msgv2 ls_message-msgv3 ls_message-msgv4.
                endloop.
              endif.
              RETURN.
            ENDIF.

          WHEN 'CHANGE'.
            IF uja_s_formula_gui-formula_name NE gs_formula_alv-formula_name. " check it.
              SELECT * FROM uja_formula_app INTO CORRESPONDING FIELDS OF TABLE lt_formula_app
              WHERE appset_id = p_appset
                AND application_id = p_appl
                AND formula_name = uja_s_formula_gui-formula_name
                AND storage_type = gd_storage_type.
              IF sy-subrc = 0.
                MESSAGE i303(uja_exception) .
                "message i001(00) with 'The formula existed!'.
                RETURN.
              ENDIF.
            ENDIF.
            TRY.
              UPDATE uja_formula_app
                SET  formula_name = uja_s_formula_gui-formula_name
                     formula_stat = gd_formula_stat
                     description = uja_s_formula_gui-description
              WHERE  appset_id = p_appset
                AND application_id = p_appl
                AND storage_type = gd_storage_type
                AND formula_name = gs_formula_alv-formula_name.
              "catch cx_sy_dynamic_osql_error.
              "  message e304(uja_exception).
              "message i001(00) with 'Error when updating formula!'.
              PERFORM validation CHANGING l_success l_message lt_message.

              IF l_success EQ abap_true. "update gt_formula_alv??
                PERFORM execute_query.
                PERFORM initial.
                MESSAGE s306(uja_exception) .

              ELSE.
                UPDATE uja_formula_app
                  SET    formula_name = gs_formula_alv-formula_name
                       formula_stat = gs_formula_alv-formula_stat
                       description = gs_formula_alv-description
                WHERE  appset_id = p_appset
                  AND application_id = p_appl
                  AND storage_type = gd_storage_type
                  AND formula_name = uja_s_formula_gui-formula_name .
                "SAZ20110808 1618458 begin
                if l_message is not initial.
                  MESSAGE l_message TYPE 'I'.
                endif.
                "SAZ20110808 1618458 end
                if lt_message is not initial.
                  loop at lt_message into ls_message.
                    message id ls_message-msgid type ls_message-msgty number ls_message-msgno
                    with ls_message-msgv1 ls_message-msgv2 ls_message-msgv3 ls_message-msgv4.
                  endloop.
                endif.
                RETURN.
              ENDIF.
            ENDTRY.

        ENDCASE.
      ENDIF.
  ENDCASE.
ENDFORM.                    " USER_COMMAND_2000
*&---------------------------------------------------------------------*
*&      Form  CHECK_SYS_FORMULA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_LF_SYS  text
*----------------------------------------------------------------------*
FORM check_sys_formula  CHANGING cf_sys TYPE uj_flg.

  DATA:
        lt_formula TYPE STANDARD TABLE OF uja_formula.      "#EC NEEDED

  CLEAR cf_sys.
  SELECT *  FROM uja_formula INTO CORRESPONDING FIELDS OF TABLE lt_formula WHERE
  formula_name = gs_formula_alv-formula_name AND storage_type = gs_formula_alv-storage_type.
  IF sy-subrc = 0.
    cf_sys = abap_true.
  ENDIF.

ENDFORM.                    " CHECK_SYS_FORMULA
*&---------------------------------------------------------------------*
*&      Module  PBO_2100  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE pbo_2100 OUTPUT.
  PERFORM pbo_2100.
ENDMODULE.                 " PBO_2100  OUTPUT
*&---------------------------------------------------------------------*
*&      Form  PBO_2100
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM pbo_2100 .

  IF go_container_editor IS INITIAL.
    CREATE OBJECT go_container_editor
      EXPORTING
        container_name = 'CONTAINER_EDITOR'.
    CREATE OBJECT go_editor
      EXPORTING
        parent = go_container_editor.
    go_editor->set_toolbar_mode( 0 ).
  ENDIF.

  "if sy-ucomm ne 'SAVE'.
  IF  gf_display IS INITIAL AND sy-ucomm EQ 'SAVE'.
    perform set_formula_stat using gd_formula_stat. " note 1831329 Yanlin@2013-3-7

  ELSE.
    perform set_formula_stat using gs_formula_alv-formula_stat. " note 1831329 Yanlin@2013-3-7
  ENDIF.

  LOOP AT SCREEN.
    IF screen-group1 = '1'.
      IF gf_display IS NOT INITIAL.
        screen-input = 0.
      ELSE.
        screen-input = 1.
      ENDIF.
    ELSE.
      screen-input = 0.
    ENDIF.

    MODIFY SCREEN.
  ENDLOOP.

  IF gf_display IS NOT INITIAL.
    go_editor->set_readonly_mode( 1 ).
  ELSE.
    go_editor->set_readonly_mode( 0 ).
  ENDIF.

ENDFORM.                                                    " PBO_2100
*&---------------------------------------------------------------------*
*&      Module  PAI_2100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE pai_2100 INPUT.
  PERFORM pai_2100.
ENDMODULE.                 " PAI_2100  INPUT
*&---------------------------------------------------------------------*
*&      Form  PAI_2100
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM pai_2100 .

  "check gf_display is initial.
  IF gd_dynnr EQ '2100' AND  gf_display EQ space.
    LOOP AT SCREEN.
      IF screen-group1 = '1'.
        screen-input = 1.
      ENDIF.
      MODIFY SCREEN.
    ENDLOOP.
  ENDIF.

*  if sy-ucomm eq 'CHANGE' or sy-ucomm eq 'DISPLAY'.
*    move-corresponding uja_s_formula_gui to gs_formula_alv.
*    gd_formula_stat = gs_formula_alv-formula_stat.
*  endif.

"  perform get_formula_stat. " note 1831329 enhance user interaction Yanlin@2013-3-7
ENDFORM.                                                    " PAI_2100
*&---------------------------------------------------------------------*
*&      Form  VALIDATION
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_L_SUCCESS  text
*      <--P_L_MESSAGE  text
*----------------------------------------------------------------------*
FORM validation  CHANGING c_flag TYPE uj_flg
                          c_message TYPE string
                          ct_message type uj0_t_message.
  "1 The formula for one application can't duplicated.(move out)
  "2 mdx Systax check. Pick one member of each dimension and call xmlQuery-axisquery.
  DATA:
        ls_user   TYPE uj0_s_user,
        ls_dim_option TYPE s_dim_option,
        lt_dim_option TYPE t_dim_option,
        l_dimension TYPE uj_dim_name,
        lo_dim        TYPE REF TO if_uja_dim_data,
        ls_q_opt      TYPE uja_s_query_opt,
        l_mem TYPE string,
        lt_sel        TYPE uj0_t_sel,
        lr_data  TYPE REF TO data,
        l_context TYPE string,
        l_xml TYPE string,
        l_query_type TYPE char20 VALUE 'axisquery',
        l_result TYPE string,                               "#EC NEEDED
        ls_message TYPE uj0_s_message,
        lt_message TYPE uj0_t_message.
  DATA: lo_metadatafactory TYPE REF TO if_uja_metadata_factory,
        lo_appl_data TYPE REF TO if_uja_application_data,
        lt_dim_list TYPE  uja_t_dim_list,
        lox_uj_static_check TYPE REF TO cx_uj_static_check,
        ls_sel TYPE uj0_s_sel.                              "#EC NEEDED

  "begin xum 281112 1793060
  DATA: lt_val_message TYPE uj0_t_message,
        ls_val_message TYPE uj0_s_message.
  "end xum 281112

*SAZ20110808 1618458 Fix program for maintaining customer measure formula begin
  data: lo_query type ref to cl_ujo_query_base,               "kal070915
*        lo_query type ref to IF_UJO_QUERY,
        l_CELL_FILTED type uj_flg,
        lt_axis type UJO_T_QUERY_DIM,
        lt_query_member type UJO_T_MEMBERS,
        ls_query_member type UJO_S_MEMBER.
*SAZ20110808 1618458 Fix program for maintaining customer measure formula end

  FIELD-SYMBOLS:
                 <lt_data> TYPE STANDARD TABLE.

  CONDENSE  p_user.
  c_flag = abap_false.
  CLEAR c_message.
  CLEAR lt_dim_option.
  CLEAR l_xml.
  CLEAR l_context.

*  if p_user is initial.
*    c_flag = abap_false.
*    c_message = 'Please input BPC user for validation on 1st Page!'.
*    return.
*  endif.
  ls_user-user_id = p_user.

  " 1 Prepare for checking
  " 1.1 set current context.
  TRY.
      CALL METHOD cl_uj_context=>set_cur_context
        EXPORTING
          i_appset_id = p_appset
          is_user     = ls_user
          i_appl_id   = p_appl.

* begin note 1831329 remove user check Yanlin@2013-3-7
" switch to admin user privilege to perform following steps
      data lo_context type ref to if_uj_context.
      lo_context = cl_uj_context=>get_cur_context( ).
      lo_context->switch_to_srvadmin( ).
* end note 1831329

      " 1.2 get model of current application
      lo_metadatafactory = cl_uja_metadata_factory=>get_factory( p_appset ).

      lo_appl_data = lo_metadatafactory->get_appl_data( p_appl ).

*  catch CX_UJA_ADMIN_ERROR.
*              message e304(uja_exception).

      " 1.3 get all the dim list.
      CALL METHOD lo_appl_data->get_dim_list
        IMPORTING
          et_dim_name = lt_dim_list.

      "2 Get one member for each dimension.
      ls_q_opt-q_option       = uja00_cs_query_opt-basmembers.
      LOOP AT lt_dim_list INTO l_dimension.
        CLEAR ls_dim_option.
        CLEAR l_mem.

        lo_dim = lo_metadatafactory->get_dim_data( l_dimension ).
        ls_dim_option-dimension = l_dimension.
        ls_dim_option-if_axis = abap_true.
        ls_sel-dimension = l_dimension.
        ls_sel-attribute = uja00_cs_attr-calc.
        ls_sel-sign =  'I'.
        ls_sel-option = 'EQ'.
        ls_sel-low = 'N'.
        CALL METHOD lo_dim->query_hier_mbr
          EXPORTING
            is_query_opt = ls_q_opt
            i_appl_id    = p_appl
            it_sel_opt   = lt_sel
            i_return_opt = if_uja_dim_data=>gc_ropt_id
          IMPORTING
            er_data      = lr_data.

        ASSIGN lr_data->* TO <lt_data>.
        IF <lt_data> IS INITIAL." raise error,each dimension should be at least one base member.
          c_flag = abap_false.
          " begin note 1831329 enhance user interaction
          c_message = text-001.
          REPLACE '&1' IN c_message WITH l_dimension.
          RETURN.
        ENDIF.
        PERFORM get_onemember USING <lt_data> CHANGING l_mem.

*SAZ20110808 1618458 Fix program for maintaining customer measure formula begin
         ls_query_member-dimension = l_dimension.
         ls_query_member-member = l_mem.
         insert ls_query_member into table lt_query_member.
         insert lt_query_member into table lt_axis.
         clear: ls_query_member, lt_query_member.

*        ls_dim_option-members = l_mem.
*        APPEND ls_dim_option TO lt_dim_option.
      ENDLOOP.

      ls_query_member-dimension = 'MEASURES'.
      ls_query_member-member = uja_s_formula_gui-formula_name.
      insert ls_query_member into table lt_query_member.
      insert lt_query_member into table lt_axis.

      APPEND 'MEASURES' to lt_dim_list.
                                                        "begin kal070915
*      CALL METHOD CL_UJO_QUERY_FACTORY=>GET_QUERY_ADAPTER
*         EXPORTING
*           I_APPSET_ID = p_appset
*           I_APPL_ID   = p_appl
*         RECEIVING
*           ADAPTER     = lo_query.
      create object lo_query type cl_ujo_query_base
        exporting
          i_appset_id = p_appset
          i_appl_id = p_appl.
                                                          "end kal070915
      call METHOD lo_appl_data->CREATE_DATA_REF
        EXPORTING
          I_DATA_TYPE   = 'T'
          IT_DIM_NAME   = lt_dim_list
          IF_TECH_NAME  = ABAP_FALSE
          IF_SIGNEDDATA = ABAP_TRUE
        IMPORTING
          ER_DATA       = lr_data.

      assign lr_data->* to <lt_data>.

*      CALL METHOD lo_query->RUN_AXIS_QUERY_SYMM              "kal070915
      CALL METHOD lo_query->IF_UJO_QUERY~RUN_AXIS_QUERY_SYMM
         EXPORTING
           IT_AXIS           = lt_axis
           I_PASSBY_SECURITY = abap_true " note 1883200 invalid formula saved successful if no auth Yanlin@2013-7-5
         IMPORTING
           ET_DATA           = <lt_data>
           E_CELL_FILTED     = l_CELL_FILTED.

*      CLEAR ls_dim_option.
*      ls_dim_option-dimension = 'MEASURES'.
*      ls_dim_option-if_axis = abap_true.
*      ls_dim_option-members = uja_s_formula_gui-formula_name .
*      APPEND ls_dim_option TO lt_dim_option.
*
*      "3 Get corresponding xml for this validation.
*      PERFORM call_xmlaxis USING lt_dim_option CHANGING l_context l_xml.
*
*      CALL FUNCTION 'UJQ_RUN_XML_QUERY'
*        EXPORTING
*          i_query_type = l_query_type
*          i_context    = l_context
*          i_filter     = l_xml
*        IMPORTING
*          e_results    = l_result
*          et_message   = lt_message.
*
*      IF lt_message IS NOT INITIAL." error.
*        LOOP AT lt_message INTO ls_message.
*          IF sy-tabix EQ 1.
*            c_message = ls_message-message.
*          ELSE.
*            CONCATENATE c_message cl_abap_char_utilities=>cr_lf ls_message-message INTO c_message.
*          ENDIF.
*        ENDLOOP.
*        RETURN.
*      ENDIF.

*SAZ20110808 1618458 Fix program for maintaining customer measure formula end

      c_flag = abap_true.

    CATCH cx_uj_static_check INTO lox_uj_static_check.

      "begin xum 281112 Note 1793060
*      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*                        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      clear ct_message.
      CALL FUNCTION 'UJ0_CONV_EX2MSG'
        EXPORTING
          io_exception     = lox_uj_static_check
        IMPORTING
          et_message_lines = ct_message.
      delete ct_message where msgid = 'SY' and msgno = '530'. " this message is useless
*      LOOP AT lt_val_message into ls_val_message.
*        MESSAGE ID ls_val_message-msgid TYPE ls_val_message-msgty NUMBER ls_val_message-msgno
*        WITH ls_val_message-MSGV1 ls_val_message-MSGV2 ls_val_message-MSGV3 ls_val_message-MSGV4.
*      ENDLOOP.
      "end xum 281112
      RETURN.

  ENDTRY.

ENDFORM.                    " VALIDATION
*&---------------------------------------------------------------------*
*&      Form  CALL_XMLAXIS
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LT_DIM_OPTION  text
*      <--P_L_CONTEXT  text
*      <--P_L_XML  text
*----------------------------------------------------------------------*
FORM call_xmlaxis  USING it_option TYPE t_dim_option
                  CHANGING c_context TYPE string
                            c_xml TYPE string.
  DATA:
        ls_dim_option TYPE s_dim_option,
 "       lt_dim_option type t_dim_option,
"        l_xml type string,
        l_cv TYPE string,
        l_temp TYPE string,
        l_axis TYPE string.
  "        l_context type string.


  CLEAR c_context.
  CLEAR c_xml.
  CONCATENATE   '<Context>'
                '<AppSet><![CDATA[' p_appset  ']]></AppSet>'
                '<UserID><![CDATA[' p_user ']]></UserID>'
                '<App><![CDATA[' p_appl ']]></App>'
                '</Context>'
               INTO c_context.                              "#EC NOTEXT

  LOOP AT it_option INTO ls_dim_option.
    IF ls_dim_option-if_axis EQ abap_true.
      PERFORM getaxisxml USING ls_dim_option CHANGING l_temp.
      CONCATENATE l_axis l_temp INTO l_axis RESPECTING BLANKS.
    ELSE.
      PERFORM getcvxml USING ls_dim_option CHANGING l_temp.
      CONCATENATE l_cv ' ' l_temp INTO l_cv RESPECTING BLANKS.
    ENDIF.
  ENDLOOP.

  CONCATENATE   '<parameter><CV application="' p_appl '"' l_cv '/>'
  '<Axes>' l_axis '</Axes><options suppresszero="true" QueryViewName=""'
  ' SqlOnly="false"/></parameter>'
  INTO c_xml.                                               "#EC NOTEXT

ENDFORM.                    " CALL_XMLAXIS

" call_xmlAxis
*&---------------------------------------------------------------------*
*&      Form  getcvxml
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->IS_OPTION  text
*      -->I_TEMP     text
*----------------------------------------------------------------------*
FORM getcvxml USING is_option TYPE s_dim_option CHANGING i_temp TYPE string.
  CLEAR i_temp.

  CONCATENATE  is_option-dimension '="' is_option-members '"' INTO i_temp.

ENDFORM.                    "getcvxml

*&---------------------------------------------------------------------*
*&      Form  GetAxisXml
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->IS_OPTION  text
*----------------------------------------------------------------------*
FORM getaxisxml USING is_option TYPE s_dim_option CHANGING i_temp TYPE string.
  DATA:

        l_dim TYPE uj_dim_name     ,
        l_mem TYPE string    .

  CLEAR i_temp.
  l_dim = is_option-dimension.
  CONCATENATE '<column dimension="' l_dim '" members="' INTO i_temp.

  l_mem = is_option-members.

  CONCATENATE i_temp l_mem '"/>' INTO i_temp.
ENDFORM.                    " GetAxisXml
*&---------------------------------------------------------------------*
*&      Form  get_onemember
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->IT_TAB     text
*      -->I_MEMBERS  text
*----------------------------------------------------------------------*
FORM get_onemember USING it_tab TYPE STANDARD TABLE CHANGING i_members TYPE string.
  DATA:   l_pos TYPE i.

  FIELD-SYMBOLS: <ls_data> TYPE any,
                  <l_cell> TYPE any.

  READ TABLE it_tab INDEX 1 ASSIGNING <ls_data>.
  l_pos = 1.
  ASSIGN COMPONENT l_pos OF STRUCTURE <ls_data> TO <l_cell>.
  i_members = <l_cell>.
ENDFORM.                    "get_onemember
*&---------------------------------------------------------------------*
*&      Form  INITIAL
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM initial .
  CLEAR ok_code.
  CLEAR pre_action.
  gd_dynnr = '1999'.
  CLEAR gs_formula_alv.
  CLEAR uja_s_formula_gui.
  uja_s_formula_gui-appset_id = p_appset.
  uja_s_formula_gui-application_id = p_appl.
ENDFORM.                    " INITIAL
*&---------------------------------------------------------------------*
*&       Class (Implementation)  lcl_handler
*&---------------------------------------------------------------------*
*        Text
*----------------------------------------------------------------------*
CLASS lcl_handler IMPLEMENTATION.

  METHOD handler_double_click.
    READ TABLE gt_formula_alv INDEX es_row_no-row_id INTO gs_formula_alv.
    g_index = es_row_no-row_id .
    gd_formula_stat = gs_formula_alv-formula_stat.

    MOVE-CORRESPONDING gs_formula_alv TO uja_s_formula_gui.

    gd_dynnr = '2100'.
    gf_display = 'X'.
  ENDMETHOD.                    "handler_double_click

ENDCLASS.               "lcl_handler

form get_formula_stat.
  data:
        lv_prefix type string,
        lv_len type i.

  call method go_editor->get_textstream
  importing
    text                     =  gv_tmp " !IMPORTANT! has to be a global variable
  exceptions
    error_cntl_call_method = 1
    not_supported_by_gui   = 2
    others                 = 3
        .

  if sy-subrc <> 0.
    message id sy-msgid type sy-msgty number sy-msgno
               with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  endif.

  cl_gui_cfw=>flush( ) .

  condense gv_tmp.

  find regex '^MEMBER \[[^]]+\].\[[^]]+\] AS\s+(.*)' ##NO_TEXT
   in gv_tmp ignoring case submatches lv_prefix.
  if sy-subrc eq 0.
    "gv_tmp = lv_prefix.       "Elw MEMEBER [Measure].[] can be specified in nested measures! 24072013 1891059
    gd_formula_stat = gv_tmp.  "Elw 24072013 for 1891059
    return.                    "Elw 24072013 for 1891059
  endif.

  perform get_prefix changing lv_prefix.

  gd_formula_stat = |{ lv_prefix }{ gv_tmp }|.
endform.

form set_formula_stat using iv_formula_stat type string.
  data:
        lv_prefix type string,
        lv_len type i,
        lv_tmp type string.
  lv_tmp = iv_formula_stat.
  if lv_tmp is not initial.
    perform get_prefix changing lv_prefix.
    lv_len = strlen( lv_prefix ).
    translate lv_tmp to upper case.
    translate lv_prefix to upper case.
    if lv_tmp+0(lv_len) eq lv_prefix.
      lv_tmp = iv_formula_stat+lv_len.
    else.
      lv_tmp = iv_formula_stat.
    endif.
    condense lv_tmp.
  endif.
  call method go_editor->set_textstream
    exporting
      text = lv_tmp.
endform.

form get_prefix changing cv_prefix type string.
  if gs_formula_alv is not initial.
    cv_prefix = |MEMBER [{ uja00_c_dim_name_measure }].[{ gs_formula_alv-formula_name }] AS |.
* begin note 1883200 error in creating w/o member prefix Yanlin@2013-7-5
  elseif uja_s_formula_gui is not initial.
    cv_prefix = |MEMBER [{ uja00_c_dim_name_measure }].[{ uja_s_formula_gui-formula_name }] AS |.
* end note 1883200
  endif.
endform.
