Phoenix CTMS
=====

This repository is a supplemental part of the Phoenix CTMS platform, see [https://github.com/phoenixctms/ctsms](https://github.com/phoenixctms/ctsms).

The following variables can be set. Variables correspond to Phoenix application parameters.

Global Variables:

| Variable Name               | Description                                 | Default Value |
|----------------------------|---------------------------------------------|---------------|
| `enable_inventory_module`  | Enables the inventory module                | `"true"`      |
| `enable_staff_module`      | Enables the staff/employee module           | `"true"`      |
| `enable_course_module`     | Enables the course management module        | `"true"`      |
| `enable_trial_module`      | Enables the clinical trial module           | `"true"`      |
| `enable_proband_module`    | Enables the proband/patient module          | `"true"`      |
| `enable_input_field_module`| Enables custom input fields                 | `"true"`      |
| `enable_user_module`       | Enables user account management             | `"true"`      |
| `enable_mass_mail_module`  | Enables bulk email/mass mail functionality  | `"true"`      |

Application Context Variables (Default Language):
| Variable Name                                      | Description                                                                 | Default Value |
|---------------------------------------------------|-----------------------------------------------------------------------------|---------------|
| `default_locale`                                  | Default system language for the application                                | `"en"`        |
| `time_zone`                                       | Default system time zone                                                   | `"UTC"`       |
| `journal_database_write_locale`                   | Language used when writing journal entries                                 | `"en"`        |
| `audit_trail_database_write_locale`               | Language used when writing audit trail logs                                | `"en"`        |
| `notifications_database_write_locale`             | Language used when saving notification records                             | `"en"`        |
| `proband_list_status_reasons_database_write_locale` | Language used for status reasons in the proband list module             | `"en"`        |
| `cv_pdf_locale`                                   | Language used for generating CV PDFs                                       | `"en"`        |
| `reimbursements_pdf_locale`                       | Language used for generating reimbursement PDFs                            | `"en"`        |
| `course_participant_list_pdf_locale`              | Language used for course participant list PDFs                             | `"en"`        |
| `proband_letter_pdf_locale`                       | Language used for generating letters to probands                           | `"en"`        |
| `course_certificate_pdf_locale`                   | Language used for generating course completion certificates                | `"en"`        |
| `ecrf_pdf_locale`                                 | Language used for generating eCRF (electronic case report form) PDFs       | `"en"`        |
| `inquiries_pdf_locale`                            | Language used for generating inquiry/export documents                      | `"en"`        |
| `proband_list_entry_tags_pdf_locale`              | Language used for entry tags in proband list PDFs                          | `"en"`        |
