# fiscal CI reports

commit `f6f01e99d7ee29d7dc9d63ecaa565b566d7a2839`, run [42146976275](https://github.com/i574n/fiscal/actions/runs/42146976275), built 2026-11-06 02:01 UTC

## Tests

193 passed, 0 failed, 0 static, 0 skipped, 0 other.

Every test passed.

## Slowest files

| file | seconds | exit |
|---|---|---|
| generator | 1333.5 | 0 |
| generated_nfe_v4 | 765 | 0 |
| generated_ubl_invoice_2_1 | 690.2 | 0 |
| generated_ubl_receiptadvice_2_1 | 342.6 | 0 |
| generated_ubl_creditnote_2_1 | 335.4 | 0 |
| generated_ubl_debitnote_2_1 | 331.1 | 0 |
| generated_ubl_despatchadvice_2_1 | 318.2 | 0 |
| corpus_checks | 292.1 | 0 |
| generated_ksef_fa_3 | 159.3 | 0 |
| generated_nfe_v3_10 | 120.5 | 0 |

## Bench (median microseconds)

| unit | parse µs | write µs | runs | bytes | os |
|---|---|---|---|---|---|
| generated_cfdi_pagos_2_0 | 51 | 24 | 31 | 9858 | Ubuntu 24.04.5 LTS |
| generated_cfdi_tfd_1_1 | 31 | 9 | 31 | 6634 | Ubuntu 24.04.5 LTS |
| generated_cfdi_v4_0 | 99 | 44 | 31 | 17391 | Ubuntu 24.04.5 LTS |
| generated_cii_d16b | 96 | 51 | 31 | 10664 | Ubuntu 24.04.5 LTS |
| generated_cl_dte_v10 | 181 | 110 | 31 | 29698 | Ubuntu 24.04.5 LTS |
| generated_cl_envio_dte_v10 | 242 | 152 | 31 | 40734 | Ubuntu 24.04.5 LTS |
| generated_cr_factura_4_4 | 80 | 42 | 31 | 29078 | Ubuntu 24.04.5 LTS |
| generated_cr_factura_compra_4_4 | 111 | 63 | 31 | 42191 | Ubuntu 24.04.5 LTS |
| generated_cr_factura_exportacion_4_4 | 107 | 70 | 31 | 38223 | Ubuntu 24.04.5 LTS |
| generated_cr_mensaje_hacienda_4_4 | 22 | 12 | 31 | 10633 | Ubuntu 24.04.5 LTS |
| generated_cr_mensaje_receptor_4_4 | 33 | 14 | 31 | 11625 | Ubuntu 24.04.5 LTS |
| generated_cr_nota_credito_4_4 | 61 | 30 | 31 | 23281 | Ubuntu 24.04.5 LTS |
| generated_cr_nota_debito_4_4 | 45 | 25 | 31 | 23219 | Ubuntu 24.04.5 LTS |
| generated_cr_recibo_pago_4_4 | 87 | 56 | 31 | 37138 | Ubuntu 24.04.5 LTS |
| generated_cr_tiquete_4_4 | 84 | 50 | 31 | 25761 | Ubuntu 24.04.5 LTS |
| generated_cte_os_v3_00 | 139 | 79 | 31 | 30721 | Ubuntu 24.04.5 LTS |
| generated_cte_os_v4_00 | 140 | 72 | 31 | 31093 | Ubuntu 24.04.5 LTS |
| generated_cte_simp_v4_00 | 214 | 126 | 31 | 47957 | Ubuntu 24.04.5 LTS |
| generated_cte_v2_00 | 285 | 142 | 31 | 38502 | Ubuntu 24.04.5 LTS |
| generated_cte_v3_00 | 165 | 85 | 31 | 39215 | Ubuntu 24.04.5 LTS |
| generated_cte_v4_00 | 156 | 84 | 31 | 39587 | Ubuntu 24.04.5 LTS |
| generated_es_facturae_3_2_2 | 195 | 108 | 31 | 77283 | Ubuntu 24.04.5 LTS |
| generated_es_verifactu | 117 | 57 | 31 | 47678 | Ubuntu 24.04.5 LTS |
| generated_fatturapa_1_2_3 | 128 | 68 | 31 | 46407 | Ubuntu 24.04.5 LTS |
| generated_gr_mydata_2_0_2 | 107 | 47 | 31 | 20398 | Ubuntu 24.04.5 LTS |
| generated_gtve_v3_00 | 146 | 85 | 31 | 42377 | Ubuntu 24.04.5 LTS |
| generated_gtve_v4_00 | 176 | 88 | 31 | 42377 | Ubuntu 24.04.5 LTS |
| generated_hu_nav_3_0 | 84 | 54 | 31 | 41137 | Ubuntu 24.04.5 LTS |
| generated_ksef_fa_3 | 170 | 91 | 31 | 44361 | Ubuntu 24.04.5 LTS |
| generated_mdfe_v1_00 | 109 | 58 | 31 | 28148 | Ubuntu 24.04.5 LTS |
| generated_mdfe_v3_00 | 115 | 58 | 31 | 27993 | Ubuntu 24.04.5 LTS |
| generated_nfe_evento_canc_v1_00 | 79 | 34 | 31 | 22537 | Ubuntu 24.04.5 LTS |
| generated_nfe_evento_cce_v1_00 | 90 | 52 | 31 | 39556 | Ubuntu 24.04.5 LTS |
| generated_nfe_evento_conf_recebto_v1_00 | 94 | 48 | 31 | 21018 | Ubuntu 24.04.5 LTS |
| generated_nfe_v2_00 | 275 | 142 | 31 | 54498 | Ubuntu 24.04.5 LTS |
| generated_nfe_v3_10 | 242 | 132 | 31 | 45260 | Ubuntu 24.04.5 LTS |
| generated_nfe_v4 | 279 | 142 | 31 | 48205 | Ubuntu 24.04.5 LTS |
| generated_pt_saft_1_04_01 | 57 | 27 | 31 | 22165 | Ubuntu 24.04.5 LTS |
| generated_ubl_applicationresponse_2_1 | 23 | 11 | 31 | 4340 | Ubuntu 24.04.5 LTS |
| generated_ubl_creditnote_2_1 | 60 | 75 | 31 | 9517 | Ubuntu 24.04.5 LTS |
| generated_ubl_debitnote_2_1 | 66 | 69 | 31 | 11718 | Ubuntu 24.04.5 LTS |
| generated_ubl_despatchadvice_2_1 | 41 | 26 | 31 | 8959 | Ubuntu 24.04.5 LTS |
| generated_ubl_invoice_2_1 | 79 | 106 | 31 | 11563 | Ubuntu 24.04.5 LTS |
| generated_ubl_receiptadvice_2_1 | 53 | 24 | 31 | 6169 | Ubuntu 24.04.5 LTS |

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
