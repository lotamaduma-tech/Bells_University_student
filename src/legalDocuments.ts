export type LegalSection = { heading:string; body:string; bullets?:string[] };
export type LegalDocument = { slug:string; title:string; summary:string; sections:LegalSection[] };

export const legalLastUpdated = '26 November 2026';
export const legalReviewNotice = 'DRAFT FOR LEGAL REVIEW — These working policies are written for MARKIO’s current university marketplace model. They are not legal advice, do not represent regulatory approval or certification, and must be reviewed by a qualified Nigerian legal practitioner before publication as binding terms.';

export const legalDocuments:LegalDocument[] = [
 {slug:'terms-of-service',title:'Terms of Service',summary:'The basic rules for using MARKIO.',sections:[
  {heading:'1. What MARKIO does',body:'MARKIO is a university-focused marketplace that helps students discover student-owned products and services. Unless a feature expressly says otherwise, MARKIO provides listing and discovery tools; buyers and sellers arrange fulfilment and payment directly with each other.'},
  {heading:'2. Eligibility and accounts',body:'You must provide accurate account information, protect your sign-in credentials and use only an account that belongs to you. MARKIO currently serves eligible members of its supported university community. Where a user is a child or otherwise lacks legal capacity to consent, MARKIO will apply age-appropriate safeguards and obtain parent or guardian consent where required by applicable law.'},
  {heading:'3. Listings and transactions',body:'Sellers are responsible for accurate descriptions, current prices, availability, lawful products and services, and clear communication. Buyers should check descriptions, seller details, condition, delivery or collection arrangements and total costs before agreeing to a transaction. MARKIO does not take custody of goods or money in ordinary direct transactions.'},
  {heading:'4. Moderation and availability',body:'MARKIO may review, restrict, hide or remove listings and accounts where reasonably necessary to enforce these policies, respond to reports, protect users or comply with law. We will use proportionate measures and provide a route to contact support about moderation decisions.'},
  {heading:'5. Limits and responsibilities',body:'Marketplace approval is not a guarantee, endorsement or warranty of a seller, product or service. Nothing in these terms removes rights that cannot lawfully be excluded under Nigerian law. Users remain responsible for their own conduct and agreements.'},
  {heading:'6. Changes and contact',body:'We may update these terms and will display a revised date. Material changes should be communicated through the platform where practicable. Use the Contact and Support page to raise a question or complaint.'}
 ]},
 {slug:'privacy-policy',title:'Privacy Policy',summary:'How MARKIO collects, uses, stores and protects personal information.',sections:[
  {heading:'1. Data controller and contact',body:'The MARKIO operating entity and its contact details must be completed and verified by the project owner before publication. This draft does not invent a legal company name, address, Data Protection Officer or NDPC registration status.'},
  {heading:'2. Information we process',body:'Depending on features used, MARKIO may process account identifiers, name and username, university affiliation, profile and store images, listing details, saved-listing records, reports, support messages, security logs and basic device or usage information. MARKIO should not collect date of birth or other sensitive information unless necessary, explained and supported by a lawful basis.'},
  {heading:'3. Purposes and lawful bases',body:'Information is used to create and secure accounts, display opted-in public profiles and listings, operate marketplace features, prevent abuse, handle reports, provide support and meet legal obligations. The operating entity must document an appropriate lawful basis for each purpose and obtain consent where required.'},
  {heading:'4. Sharing and international transfers',body:'Information may be processed by hosting, database, storage, authentication, analytics or communications providers acting under appropriate safeguards. MARKIO should identify relevant recipients, assess cross-border transfers under the Nigeria Data Protection Act and applicable NDPC guidance, and avoid selling personal data.'},
  {heading:'5. Retention and security',body:'Personal information should be kept only for as long as necessary for the stated purpose, legal obligations, dispute handling or security. Access controls, row-level security, least privilege, secure storage and incident response measures should protect information against unauthorised access, loss or disclosure.'},
  {heading:'6. Your rights',body:'Subject to applicable law, users may request access to their information, correction, erasure, restriction, objection, portability where applicable, and withdrawal of consent where processing relies on consent. Users may also complain to the Nigeria Data Protection Commission. Requests should be sent through Contact and Support.'},
  {heading:'7. Children and younger users',body:'MARKIO must assess whether a user is a child under applicable law, use proportionate age-assurance methods and obtain parent or guardian consent where required. Public profile discovery and sharing should be off by default for younger users unless an appropriate lawful basis and safeguards are documented. Do not publish private contact details or sensitive information.'},
  {heading:'8. Cookies and tracking',body:'Strictly necessary technologies may be used for sign-in, security and core functionality. Any optional analytics, advertising or tracking cookies must be described and presented with the choices required by applicable law and NDPC guidance.'}
 ]},
 {slug:'marketplace-rules',title:'Marketplace Rules and Guidelines',summary:'Standards for trustworthy listings and respectful marketplace use.',sections:[
  {heading:'Accurate listings',body:'Every listing must describe the actual product or service, its condition, availability, material limitations and full price clearly. Photos must represent the item or service and must not be misleading.'},
  {heading:'Fair conduct',body:'Do not impersonate another person or business, manipulate reviews or engagement, harass users, discriminate unlawfully, threaten others or use MARKIO to facilitate fraud.'},
  {heading:'Seller responsibility',body:'Sellers must have the right to offer what they list, comply with applicable safety and licensing rules, honour agreed terms and promptly correct inaccurate information.'},
  {heading:'Buyer responsibility',body:'Buyers should verify relevant details, agree on fulfilment and payment arrangements before proceeding, and report suspicious behaviour through the platform.'}
 ]},
 {slug:'seller-terms',title:'Seller Terms and Conditions',summary:'Additional obligations for student vendors.',sections:[
  {heading:'Seller eligibility',body:'Seller access is subject to MARKIO’s application and approval process. Approval may be reviewed if account information changes or policy concerns arise.'},
  {heading:'Seller obligations',body:'You must provide truthful business and contact details, maintain accurate prices and availability, respond fairly to enquiries, fulfil accepted commitments and comply with applicable Nigerian consumer, tax, product-safety and sector rules.'},
  {heading:'Content and rights',body:'You must own or have permission to use all listing images, names, logos and descriptions. You grant MARKIO a limited licence to host and display that content to operate the marketplace.'},
  {heading:'Suspension',body:'MARKIO may pause listings or seller access where there is a credible safety, fraud, legal or policy concern. Sellers may contact support to request review.'}
 ]},
 {slug:'buyer-guidelines',title:'Buyer / Student Guidelines',summary:'Practical guidance for safer campus purchases.',sections:[
  {heading:'Before agreeing',body:'Read the full description, confirm the total price, condition, availability, collection or delivery method and any additional charges. Ask the seller questions before committing.'},
  {heading:'Payments and fulfilment',body:'Ordinary MARKIO listings connect buyers and sellers directly. Confirm payment details independently and keep receipts or written agreements. Do not share passwords, verification codes or unnecessary personal information.'},
  {heading:'Problems',body:'Contact the seller first where appropriate, keep relevant records and submit a MARKIO report if a listing or interaction appears misleading, unsafe or abusive. MARKIO may help moderate the platform but does not guarantee a private transaction.'}
 ]},
 {slug:'prohibited-products',title:'Prohibited Products and Services Policy',summary:'Items and activities that must not be advertised or offered on MARKIO.',sections:[
  {heading:'Prohibited offers',body:'MARKIO does not allow offers that are unlawful, unsafe, exploitative or incompatible with a student marketplace. This includes illegal goods or services, counterfeit or stolen property, dangerous or regulated items offered without lawful authorisation, controlled substances, intoxicants, tobacco or nicotine products, adult sexual services, and goods or services that facilitate fraud, abuse or harm.'},
  {heading:'Restricted or regulated offers',body:'Where an item or service is regulated, sellers must not list it unless the offer is lawful and all required licences, approvals, age restrictions and safety requirements are met. MARKIO may prohibit additional categories as a precaution.'},
  {heading:'Enforcement',body:'Listings may be removed and accounts restricted while credible concerns are reviewed. Serious matters may be referred to appropriate authorities where required by law.'}
 ]},
 {slug:'reporting-moderation',title:'Reporting and Moderation Policy',summary:'How reports are handled and how moderation protects users.',sections:[
  {heading:'Submitting a report',body:'Users may report a listing for misleading information, suspected fraud, inappropriate content, suspicious seller conduct or another policy concern. Reports should be accurate and include only relevant details.'},
  {heading:'Review process',body:'Reports are available only to authorised moderation personnel. MARKIO may assess listing content, account history and relevant information, then request clarification, restrict a listing, issue a warning or take other proportionate action.'},
  {heading:'Privacy and abuse',body:'Reporter identity and report details are not displayed publicly. Repeated, knowingly false or abusive reports may themselves be reviewed. Users can contact support if they believe a decision was mistaken.'}
 ]},
 {slug:'intellectual-property',title:'Intellectual Property and Copyright Policy',summary:'Respect for names, images, designs and other protected works.',sections:[
  {heading:'Use only authorised content',body:'Do not upload photographs, logos, artwork, text, trademarks or other material unless you created it or have permission to use it for the listing.'},
  {heading:'Report infringement',body:'A rights holder or authorised representative may contact MARKIO with the relevant work, listing URL, explanation of the alleged infringement and contact details sufficient to review the claim.'},
  {heading:'Response',body:'MARKIO may temporarily restrict disputed content while reviewing a sufficiently detailed notice. Repeated infringement may result in account restrictions. This process does not replace remedies available under Nigerian law.'}
 ]},
 {slug:'community-standards',title:'Community Standards',summary:'The behaviour expected from everyone using MARKIO.',sections:[
  {heading:'Respect',body:'Communicate honestly and respectfully. Harassment, threats, hate, discrimination, exploitation, intimidation and sharing another person’s private information without permission are not allowed.'},
  {heading:'Integrity',body:'Do not misrepresent identity, business ownership, product condition, price, availability, endorsements or transaction outcomes.'},
  {heading:'Safety',body:'Do not use MARKIO to arrange unlawful or harmful activity. Report credible safety concerns promptly and do not retaliate against people who raise concerns in good faith.'}
 ]},
 {slug:'suspension-termination',title:'Account Suspension and Termination Policy',summary:'When and how account restrictions may be applied.',sections:[
  {heading:'Reasons for action',body:'MARKIO may issue warnings, remove content, pause seller privileges, temporarily suspend or terminate accounts for serious or repeated policy violations, fraud, threats to user safety, legal requirements or attempts to evade prior enforcement.'},
  {heading:'Proportionate review',body:'Where practicable, MARKIO will consider severity, evidence, recurrence and risk. Users should receive an explanation and a support route unless notice would compromise safety, an investigation or a legal obligation.'},
  {heading:'Appeals and retained records',body:'A user may request review through Contact and Support. Some records may be retained where necessary for security, dispute resolution or legal obligations, even after an account is closed.'}
 ]},
 {slug:'cookie-policy',title:'Cookie Policy',summary:'How necessary and optional browser storage may be used.',sections:[
  {heading:'Necessary technologies',body:'MARKIO may use session storage, authentication tokens and similar technologies needed for secure sign-in, network stability, accessibility and core features.'},
  {heading:'Optional technologies',body:'Optional analytics or advertising technologies should not be enabled until MARKIO provides clear information and obtains the choices or consent required by applicable law. Users should be able to change their choices.'},
  {heading:'Current implementation',body:'The project owner must audit deployed scripts, SDKs and hosting behaviour before this draft can accurately describe every cookie or tracking tool in use.'}
 ]},
 {slug:'contact-support',title:'Contact and Support',summary:'How to ask questions, raise a complaint or exercise privacy rights.',sections:[
  {heading:'Marketplace support',body:'Use the support contact published in the MARKIO application to report a technical problem, listing concern, seller dispute or account issue. The project owner must add and verify an operational support email and response process before launch.'},
  {heading:'Privacy requests',body:'Requests to access, correct, erase, restrict or object to processing should identify the account concerned and describe the request. MARKIO should verify identity proportionately and respond within the time required by applicable law.'},
  {heading:'External complaints',body:'Users may also contact the Nigeria Data Protection Commission about data-protection concerns or the Federal Competition and Consumer Protection Commission about relevant consumer-protection matters.'}
 ]}
];
