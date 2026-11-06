# fiscal CI reports

commit `f6f01e99d7ee29d7dc9d63ecaa565b566d7a2839`, run [42146976275](https://github.com/i574n/fiscal/actions/runs/42146976275), built 2026-11-06 02:04 UTC

## Tests

193 passed, 0 failed, 0 static, 0 skipped, 0 other.

Every test passed.

## Slowest files

| file | seconds | exit |
|---|---|---|
| generator | 1960.4 | 0 |
| generated_ubl_invoice_2_1 | 1567.7 | 0 |
| generated_nfe_v4 | 691.2 | 0 |
| generated_ubl_creditnote_2_1 | 461.7 | 0 |
| generated_ubl_debitnote_2_1 | 453.9 | 0 |
| generated_ubl_receiptadvice_2_1 | 423.1 | 0 |
| generated_ubl_despatchadvice_2_1 | 415.3 | 0 |
| corpus_checks | 370 | 0 |
| generated_cii_d16b | 161 | 0 |
| generated_ksef_fa_3 | 153.7 | 0 |

## Bench (median microseconds)

| unit | parse µs | write µs | runs | bytes | os |
|---|---|---|---|---|---|
| generated_cfdi_pagos_2_0 | 40 | 21 | 31 | 9858 | Microsoft Windows 10.0.26100 |
| generated_cfdi_tfd_1_1 | 30 | 9 | 31 | 6634 | Microsoft Windows 10.0.26100 |
| generated_cfdi_v4_0 | 69 | 38 | 31 | 17391 | Microsoft Windows 10.0.26100 |
| generated_cii_d16b | 128 | 40 | 31 | 10664 | Microsoft Windows 10.0.26100 |
| generated_cl_dte_v10 | 117 | 90 | 31 | 29698 | Microsoft Windows 10.0.26100 |
| generated_cl_envio_dte_v10 | 150 | 118 | 31 | 40734 | Microsoft Windows 10.0.26100 |
| generated_cr_factura_4_4 | 76 | 53 | 31 | 29078 | Microsoft Windows 10.0.26100 |
| generated_cr_factura_compra_4_4 | 108 | 76 | 31 | 42191 | Microsoft Windows 10.0.26100 |
| generated_cr_factura_exportacion_4_4 | 99 | 70 | 31 | 38223 | Microsoft Windows 10.0.26100 |
| generated_cr_mensaje_hacienda_4_4 | 26 | 16 | 31 | 10633 | Microsoft Windows 10.0.26100 |
| generated_cr_mensaje_receptor_4_4 | 24 | 16 | 31 | 11625 | Microsoft Windows 10.0.26100 |
| generated_cr_nota_credito_4_4 | 56 | 38 | 31 | 23281 | Microsoft Windows 10.0.26100 |
| generated_cr_nota_debito_4_4 | 55 | 36 | 31 | 23219 | Microsoft Windows 10.0.26100 |
| generated_cr_recibo_pago_4_4 | 87 | 66 | 31 | 37138 | Microsoft Windows 10.0.26100 |
| generated_cr_tiquete_4_4 | 63 | 43 | 31 | 25761 | Microsoft Windows 10.0.26100 |
| generated_cte_os_v3_00 | 134 | 89 | 31 | 30721 | Microsoft Windows 10.0.26100 |
| generated_cte_os_v4_00 | 137 | 92 | 31 | 31093 | Microsoft Windows 10.0.26100 |
| generated_cte_simp_v4_00 | 208 | 151 | 31 | 47957 | Microsoft Windows 10.0.26100 |
| generated_cte_v2_00 | 171 | 118 | 31 | 38502 | Microsoft Windows 10.0.26100 |
| generated_cte_v3_00 | 179 | 117 | 31 | 39215 | Microsoft Windows 10.0.26100 |
| generated_cte_v4_00 | 177 | 120 | 31 | 39587 | Microsoft Windows 10.0.26100 |
| generated_es_facturae_3_2_2 | 194 | 133 | 31 | 77283 | Microsoft Windows 10.0.26100 |
| generated_es_verifactu | 148 | 69 | 31 | 47678 | Microsoft Windows 10.0.26100 |
| generated_fatturapa_1_2_3 | 122 | 95 | 31 | 46407 | Microsoft Windows 10.0.26100 |
| generated_gr_mydata_2_0_2 | 59 | 37 | 31 | 20398 | Microsoft Windows 10.0.26100 |
| generated_gtve_v3_00 | 171 | 117 | 31 | 42377 | Microsoft Windows 10.0.26100 |
| generated_gtve_v4_00 | 170 | 123 | 31 | 42377 | Microsoft Windows 10.0.26100 |
| generated_hu_nav_3_0 | 90 | 61 | 31 | 41137 | Microsoft Windows 10.0.26100 |
| generated_ksef_fa_3 | 171 | 106 | 31 | 44361 | Microsoft Windows 10.0.26100 |
| generated_mdfe_v1_00 | 109 | 78 | 31 | 28148 | Microsoft Windows 10.0.26100 |
| generated_mdfe_v3_00 | 109 | 72 | 31 | 27993 | Microsoft Windows 10.0.26100 |
| generated_nfe_evento_canc_v1_00 | 71 | 45 | 31 | 22537 | Microsoft Windows 10.0.26100 |
| generated_nfe_evento_cce_v1_00 | 77 | 55 | 31 | 39556 | Microsoft Windows 10.0.26100 |
| generated_nfe_evento_conf_recebto_v1_00 | 65 | 42 | 31 | 21018 | Microsoft Windows 10.0.26100 |
| generated_nfe_v2_00 | 264 | 179 | 31 | 54498 | Microsoft Windows 10.0.26100 |
| generated_nfe_v3_10 | 221 | 143 | 31 | 45260 | Microsoft Windows 10.0.26100 |
| generated_nfe_v4 | 262 | 157 | 31 | 48205 | Microsoft Windows 10.0.26100 |
| generated_pt_saft_1_04_01 | 62 | 38 | 31 | 22165 | Microsoft Windows 10.0.26100 |
| generated_ubl_applicationresponse_2_1 | 24 | 9 | 31 | 4340 | Microsoft Windows 10.0.26100 |
| generated_ubl_creditnote_2_1 | 70 | 57 | 31 | 9517 | Microsoft Windows 10.0.26100 |
| generated_ubl_debitnote_2_1 | 74 | 51 | 31 | 11718 | Microsoft Windows 10.0.26100 |
| generated_ubl_despatchadvice_2_1 | 45 | 20 | 31 | 8959 | Microsoft Windows 10.0.26100 |
| generated_ubl_invoice_2_1 | 92 | 87 | 31 | 11563 | Microsoft Windows 10.0.26100 |
| generated_ubl_receiptadvice_2_1 | 35 | 12 | 31 | 6169 | Microsoft Windows 10.0.26100 |

## Examples

| example | bytes | verdict | first message |
|---|---|---|---|
| generated_cfdi_v4_0_example.xml | 597 | valid |  |
| generated_ubl_invoice_2_1_example.xml | 687 | valid |  |
| generated_ubl_creditnote_2_1_example.xml | 624 | valid |  |
| generated_ubl_debitnote_2_1_example.xml | 694 | valid |  |
| generated_ubl_despatchadvice_2_1_example.xml | 610 | valid |  |
| generated_ubl_receiptadvice_2_1_example.xml | 519 | valid |  |
| generated_ubl_applicationresponse_2_1_example.xml | 466 | valid |  |
| generated_fatturapa_1_2_3_example.xml | 1573 | valid |  |
| generated_ksef_fa_3_example.xml | 1480 | valid |  |
| generated_cfdi_pagos_2_0_example.xml | 356 | valid |  |
| generated_cfdi_tfd_1_1_example.xml | 264 | valid |  |
| generated_cl_dte_v10_example.xml | 991 | valid |  |
| generated_cl_envio_dte_v10_example.xml | 1387 | valid |  |
| generated_cr_factura_4_4_example.xml | 1025 | valid |  |
| generated_cr_factura_compra_4_4_example.xml | 1454 | valid |  |
| generated_cr_factura_exportacion_4_4_example.xml | 1331 | valid |  |
| generated_cr_mensaje_hacienda_4_4_example.xml | 427 | valid |  |
| generated_cr_mensaje_receptor_4_4_example.xml | 459 | valid |  |
| generated_cr_nota_credito_4_4_example.xml | 842 | valid |  |
| generated_cr_nota_debito_4_4_example.xml | 839 | valid |  |
| generated_cr_recibo_pago_4_4_example.xml | 1288 | valid |  |
| generated_cr_tiquete_4_4_example.xml | 918 | valid |  |
| generated_es_facturae_3_2_2_example.xml | 2571 | valid |  |
| generated_es_verifactu_example.xml | 1810 | valid |  |
| generated_gr_mydata_2_0_2_example.xml | 705 | valid |  |
| generated_nfe_v4_example.xml | 1598 | valid |  |
| generated_nfe_evento_canc_v1_00_example.xml | 770 | valid |  |
| generated_nfe_evento_cce_v1_00_example.xml | 1319 | valid |  |
| generated_nfe_evento_conf_recebto_v1_00_example.xml | 721 | valid |  |
| generated_nfe_v2_00_example.xml | 1801 | valid |  |
| generated_nfe_v3_10_example.xml | 1503 | valid |  |
| generated_cte_v2_00_example.xml | 1285 | valid |  |
| generated_cte_v3_00_example.xml | 1308 | valid |  |
| generated_cte_v4_00_example.xml | 1320 | valid |  |
| generated_cte_os_v3_00_example.xml | 1034 | valid |  |
| generated_cte_os_v4_00_example.xml | 1046 | valid |  |
| generated_cte_simp_v4_00_example.xml | 1590 | valid |  |
| generated_gtve_v3_00_example.xml | 1410 | valid |  |
| generated_gtve_v4_00_example.xml | 1410 | valid |  |
| generated_mdfe_v1_00_example.xml | 952 | valid |  |
| generated_mdfe_v3_00_example.xml | 947 | valid |  |
| generated_in_gst_inv01_1_1_example.json | 459 | valid |  |

## Canon census (the 24 required EN 16931 terms)

| family | bound | implied | derived | national code | not carried |
|---|---|---|---|---|---|
| NF-e 4.00 | 11 | 2 | 4 | 4 | 3 |
| CFDI 4.0 | 11 | 1 | 5 | 3 | 4 |
