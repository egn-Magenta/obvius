## What does this MR do?
<!--
Briefly describe what this MR is about.
Examples:
 Adds new document type: MyNewDocumentType
 Fixes js error in <some functionality>
-->


## Code quality checklist

- [ ] I have added unit tests or made a conscious decision not to
- [ ] The MR does not introduce indentation or charset issues
- [ ] The code contains inline and/or POD documentation where relevant
- [ ] The feature does not involve database changes, or: all scripts are idempotent
- [ ] The branch has been rebased on top of the latest version of development and all commits reference the ticket id (eg. `[#12345] Implement featureX in Y`)
- [ ] All commits on this MR are atomic/logical, or: the MR is set to be squashed into a single commit on merge

## Pre-review instructions

* Ensure that the title of this MR contains the relevant ticket no., formatted like `[#12345]` or `#12345`
* Add a link to any related MR in `obvius`
* Add deployment notes on the corresponding Redmine ticket if relevant
* `@assign` this MR to your choice of reviewer
* Set the corresponding Redmine ticket to `Release Management: QA (Int)`, assign it to the reviewer and add a link to this page to the `Merge request` field. Ensure that ticket is linked to an upcoming deployment

---

## Review checklist

- [ ] The code is understandable, well-structured and sufficiently documented
- [ ] I would be able to deploy this feature and verify that it's working without further input from the author
- [ ] I have checked out the code and tested locally, tested the changes on cmstest01.ku.dk or thorougly vetted the code

If this MR contains database changes, please do a dry run of a potential deployment in your local environment.

## Merge instructions

* If squashing, make sure the squash commit message makes sense
* Set the corresponding Redmine ticket to `Release Management: Approved` and unassign yourself