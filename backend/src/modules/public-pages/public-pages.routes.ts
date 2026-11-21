import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { sendContactUsEmail } from '../../utils/mailer';
import { ok, fail } from '../../utils/response';

export const publicPagesRouter = Router();

const contactSchema = z.object({
  name: z.string().trim().min(2, 'Name must be at least 2 characters').max(100),
  email: z.string().trim().email('Please provide a valid email address').max(150),
  phone: z.string().trim().max(30).optional().default(''),
  subject: z.string().trim().min(2, 'Subject must be at least 2 characters').max(150).optional().default('General Inquiry'),
  message: z.string().trim().min(5, 'Message must be at least 5 characters').max(3000),
});

/**
 * Handle Contact Us Form Submissions
 * Mails details directly to it.nbdeveloper@gmail.com
 */
async function handleContactSubmission(req: Request, res: Response) {
  try {
    const parsed = contactSchema.safeParse(req.body);
    if (!parsed.success) {
      const firstErr = parsed.error.issues[0]?.message || 'Invalid form submission';
      return res.status(400).json(fail(firstErr));
    }

    const { name, email, phone, subject, message } = parsed.data;
    const clientIp = (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() || req.ip || '';

    await sendContactUsEmail({
      name,
      email,
      phone,
      subject,
      message,
      ip: clientIp,
    });

    return res.json(
      ok({
        sent: true,
        message: 'Thank you for reaching out. Your message has been sent to our IT team at it.nbdeveloper@gmail.com. We will respond promptly.',
      })
    );
  } catch (err: any) {
    console.error('[PublicPages] Error sending contact email:', err);
    return res.status(500).json(fail(err.message || 'Failed to submit contact message. Please try again.'));
  }
}

// Support both endpoint mountings
publicPagesRouter.post('/api/contactus', handleContactSubmission);
publicPagesRouter.post('/api/contact-us', handleContactSubmission);
publicPagesRouter.post('/contactus/submit', handleContactSubmission);
publicPagesRouter.post('/contactus', handleContactSubmission);

// Public HTML view: /privacypolicy
publicPagesRouter.get('/privacypolicy', (_req: Request, res: Response) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(PRIVACY_POLICY_HTML);
});

// Public HTML view: /contactus
publicPagesRouter.get('/contactus', (_req: Request, res: Response) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(CONTACT_US_HTML);
});

export const PRIVACY_POLICY_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Privacy Policy — NB Infra Projects LTD.</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Playfair+Display:ital,wght@0,600;0,700;1,600&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #0A0F1D;
      --card-bg: rgba(17, 24, 39, 0.94);
      --card-border: rgba(255, 255, 255, 0.08);
      --gold: #D4AF37;
      --gold-light: #F7E7A9;
      --gold-dark: #A38020;
      --text: #F3F4F6;
      --text-muted: #9CA3AF;
      --accent: #F59E0B;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    body {
      background: var(--bg);
      background-image: 
        radial-gradient(ellipse at 15% 10%, rgba(212, 175, 55, 0.12) 0px, transparent 40%),
        radial-gradient(ellipse at 85% 85%, rgba(59, 130, 246, 0.08) 0px, transparent 40%);
      color: var(--text);
      min-height: 100vh;
      line-height: 1.7;
      padding: 36px 18px 80px;
    }
    .container {
      max-width: 900px;
      margin: 0 auto;
    }
    .header {
      text-align: center;
      padding: 24px 0 40px;
      border-bottom: 1px solid var(--card-border);
      margin-bottom: 36px;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 18px;
      border-radius: 999px;
      background: rgba(212, 175, 55, 0.12);
      border: 1px solid rgba(212, 175, 55, 0.35);
      color: var(--gold-light);
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 1.5px;
      text-transform: uppercase;
      margin-bottom: 16px;
    }
    h1 {
      font-family: 'Playfair Display', Georgia, serif;
      font-size: 36px;
      font-weight: 700;
      color: #FFFFFF;
      letter-spacing: -0.5px;
      margin-bottom: 10px;
    }
    .subtitle {
      font-size: 15px;
      color: var(--text-muted);
    }
    .nav-links {
      margin-top: 18px;
      display: flex;
      justify-content: center;
      gap: 16px;
      font-size: 13.5px;
    }
    .nav-links a {
      color: var(--gold);
      text-decoration: none;
      font-weight: 600;
      transition: color 0.2s;
    }
    .nav-links a:hover {
      color: #FFFFFF;
      text-decoration: underline;
    }
    .policy-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 20px;
      padding: 40px;
      box-shadow: 0 20px 40px -15px rgba(0, 0, 0, 0.5);
      backdrop-filter: blur(12px);
    }
    h2 {
      font-size: 20px;
      font-weight: 700;
      color: var(--gold-light);
      margin-top: 36px;
      margin-bottom: 14px;
      display: flex;
      align-items: center;
      gap: 10px;
      border-left: 3px solid var(--gold);
      padding-left: 12px;
    }
    h2:first-of-type {
      margin-top: 0;
    }
    p {
      color: #D1D5DB;
      font-size: 14.5px;
      margin-bottom: 14px;
    }
    ul {
      margin: 10px 0 18px 24px;
      color: #D1D5DB;
      font-size: 14px;
    }
    li {
      margin-bottom: 8px;
    }
    li strong {
      color: #FFFFFF;
    }
    .jurisdiction-box {
      margin: 32px 0 16px;
      padding: 22px 24px;
      background: rgba(212, 175, 55, 0.08);
      border: 1px solid rgba(212, 175, 55, 0.3);
      border-radius: 14px;
    }
    .jurisdiction-box h3 {
      font-size: 16px;
      color: var(--gold-light);
      margin-bottom: 8px;
      font-weight: 700;
    }
    .jurisdiction-box p {
      margin-bottom: 0;
      color: #F3F4F6;
      font-size: 14px;
    }
    .footer {
      text-align: center;
      margin-top: 40px;
      font-size: 12.5px;
      color: var(--text-muted);
    }
    @media (max-width: 640px) {
      .policy-card {
        padding: 24px 20px;
      }
      h1 {
        font-size: 28px;
      }
      h2 {
        font-size: 18px;
      }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="badge">Enterprise Governance</div>
      <h1>Privacy Policy</h1>
      <p class="subtitle">NB Infra Projects LTD. · CRM, HRMS & ERP Enterprise Solutions</p>
      <div class="nav-links">
        <a href="/login">← Return to Login</a>
        <span style="color: var(--card-border)">|</span>
        <a href="/contactus">Contact Us</a>
      </div>
    </div>

    <div class="policy-card">
      <h2>1. Introduction & Scope</h2>
      <p>
        <strong>NB Infra Projects LTD.</strong> ("Company", "we", "us", or "our") is committed to protecting the privacy, security, and integrity of personal and operational information handled across our enterprise platforms. This Privacy Policy details our practices concerning the collection, storage, processing, and safeguarding of data gathered through our NB CRM, HRMS, and ERP systems, including our mobile applications, web portals, APIs, and associated cloud infrastructure.
      </p>
      <p>
        This policy applies to authorized employees, contractors, field representatives, vendors, corporate clients, and end-users who access or utilize platforms operated by NB Infra Projects LTD.
      </p>

      <h2>2. Categories of Information Collected</h2>
      <p>In operating our enterprise platforms, we collect and process the following classifications of data:</p>
      <ul>
        <li><strong>Identity & Employment Records:</strong> Full legal name, official employee identifier, system role, department, designation, organizational branch, and statutory identification documents required for employment verification.</li>
        <li><strong>Commercial & CRM Information:</strong> Customer lead profiles, real estate inquiry records, site visit logs, unit booking preferences, quotation lifecycles, and transaction documentation.</li>
        <li><strong>Geolocation & Attendance Records:</strong> Real-time GPS location coordinates, punch-in/out timestamps, geofenced perimeter verifications, and travel trajectories collected strictly for workforce attendance, field trip verification, and travel reimbursement audits.</li>
        <li><strong>Device, Network & System Logs:</strong> Device make and model, unique operating system identifiers, IP address, network carrier details, system crash dumps, and application session telemetry.</li>
        <li><strong>Communications & Telephony Logs:</strong> Inbound and outbound telecaller telephony metadata (call duration, timestamp, agent attribution, recording audio where enabled for quality audits), customer follow-up notes, and internal support tickets.</li>
      </ul>

      <h2>3. Purpose and Legal Grounds of Processing</h2>
      <p>Information collected by NB Infra Projects LTD. is processed strictly for legitimate corporate, contractual, and regulatory objectives:</p>
      <ul>
        <li><strong>Enterprise Operations:</strong> Administering construction ERP workflows, managing contractor work orders, monitoring site progress (DPR), coordinating material inventory, and facilitating real estate sales pipeline management.</li>
        <li><strong>Workforce Management:</strong> Validating workplace attendance, processing monthly payroll calculations, managing leave approvals, and authenticating authorized personnel.</li>
        <li><strong>Security & Access Control:</strong> Safeguarding enterprise networks, auditing user actions, identifying unauthorized intrusion attempts, and preventing fraudulent punches or proxy logins.</li>
        <li><strong>Statutory & Regulatory Obligations:</strong> Ensuring compliance with applicable labor codes, commercial regulations, construction standards, and corporate governance laws.</li>
      </ul>

      <h2>4. Geolocation and Field Tracking Policy</h2>
      <p>
        Certain features of our mobile applications require access to device location services (both foreground and background) to facilitate accurate geofenced attendance punches and route verification for field workforce personnel.
      </p>
      <ul>
        <li>Location data is recorded exclusively during active work hours or designated on-duty field trips initiated by the user.</li>
        <li>Tracking automatically concludes upon shift sign-out or trip completion.</li>
        <li>Location telemetry is utilized solely for organizational accountability and is never commercialized, sold, or shared with third-party advertisers.</li>
      </ul>

      <h2>5. Data Security & Storage Architecture</h2>
      <p>
        NB Infra Projects LTD. employs multi-tiered technical, administrative, and physical security measures to safeguard corporate and personal information:
      </p>
      <ul>
        <li><strong>Cryptographic Envelopes:</strong> High-sensitivity payload transactions between clients and backend servers are protected using double AES-GCM transport envelope encryption alongside HTTPS / TLS 1.3 encrypted transport layers.</li>
        <li><strong>Segregated Architecture:</strong> Relational and time-series data reside in hardened enterprise databases with restricted internal network visibility.</li>
        <li><strong>Role-Based Access Control (RBAC):</strong> Access permissions are enforced at granular levels. System operators and personnel are granted access strictly on a least-privilege, need-to-know basis.</li>
        <li><strong>Auditing & Monitoring:</strong> Comprehensive audit logs track authentication attempts, record modifications, and document access across all modules.</li>
      </ul>

      <h2>6. Data Retention & Archival</h2>
      <p>
        We retain collected information for the duration necessary to satisfy the operational objectives outlined in this policy, contractual agreements, and applicable statutory retention mandates. When data is no longer required for legitimate business purposes or statutory compliance, it is securely anonymized or permanently purged in accordance with our enterprise retention standards.
      </p>

      <h2>7. Information Sharing & Third-Party Disclosure</h2>
      <p>
        NB Infra Projects LTD. does not sell, trade, or monetize personal information. Information is shared only under strict conditions:
      </p>
      <ul>
        <li><strong>Infrastructure Service Providers:</strong> Trusted enterprise technology partners providing cloud hosting, database management, SMS/WhatsApp gateways, telephony switching, and map visualization services under binding non-disclosure agreements.</li>
        <li><strong>Legal & Regulatory Mandates:</strong> Where disclosure is strictly required pursuant to court orders, governmental warrants, or statutory directives under Indian law.</li>
        <li><strong>Corporate Integrity:</strong> In circumstances necessary to investigate fraud, security breaches, or violations of enterprise usage protocols.</li>
      </ul>

      <h2>8. Children's Privacy</h2>
      <p>
        Our systems and enterprise services are intended exclusively for authorized corporate personnel, business partners, and clients who have attained the legal age of majority (18 years or older). We do not knowingly solicit or collect data pertaining to minors.
      </p>

      <div class="jurisdiction-box">
        <h3>9. Governing Law & Exclusive Jurisdiction</h3>
        <p>
          This Privacy Policy, all matters arising out of or relating to this Platform, its terms, data handling practices, and any related transactions or disputes shall be governed by, construed, and enforced in accordance with the laws of the Republic of India. Any legal dispute, controversy, claim, or proceeding arising under or in connection with this Policy or the services provided by NB Infra Projects LTD. shall be subject to the exclusive jurisdiction of the competent courts located in <strong>Ahmedabad, Gujarat, India</strong>.
        </p>
      </div>

      <h2>10. Policy Updates & Amendments</h2>
      <p>
        NB Infra Projects LTD. reserves the right to amend, update, or modify this Privacy Policy periodically to reflect technological evolutions, organizational restructuring, or statutory amendments. Material revisions will be reflected on this portal with an updated revision notice. Continued utilization of our platforms following such updates signifies formal acknowledgment of the revised provisions.
      </p>
      <p style="font-size: 13px; color: var(--text-muted); margin-top: 20px;">
        <em>Note on Inquiries: In accordance with our internal governance policy, all platform-related inquiries and administrative service requests must be submitted through authorized internal corporate channels.</em>
      </p>
    </div>

    <div class="footer">
      © 2026 NB Infra Projects LTD. All rights reserved. Confidential & Proprietary Enterprise System.
    </div>
  </div>
</body>
</html>`;

export const CONTACT_US_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Contact Us — NB Infra Projects LTD.</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Playfair+Display:ital,wght@0,600;0,700;1,600&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #0A0F1D;
      --card-bg: rgba(17, 24, 39, 0.94);
      --card-border: rgba(255, 255, 255, 0.08);
      --gold: #D4AF37;
      --gold-light: #F7E7A9;
      --text: #F3F4F6;
      --text-muted: #9CA3AF;
      --input-bg: #111827;
      --input-border: #374151;
      --accent: #F59E0B;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    body {
      background: var(--bg);
      background-image: 
        radial-gradient(ellipse at 15% 10%, rgba(212, 175, 55, 0.12) 0px, transparent 40%),
        radial-gradient(ellipse at 85% 85%, rgba(59, 130, 246, 0.08) 0px, transparent 40%);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 36px 18px 80px;
    }
    .container {
      width: 100%;
      max-width: 680px;
    }
    .header {
      text-align: center;
      padding: 24px 0 32px;
      margin-bottom: 24px;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 18px;
      border-radius: 999px;
      background: rgba(212, 175, 55, 0.12);
      border: 1px solid rgba(212, 175, 55, 0.35);
      color: var(--gold-light);
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 1.5px;
      text-transform: uppercase;
      margin-bottom: 16px;
    }
    h1 {
      font-family: 'Playfair Display', Georgia, serif;
      font-size: 34px;
      font-weight: 700;
      color: #FFFFFF;
      letter-spacing: -0.5px;
      margin-bottom: 8px;
    }
    .subtitle {
      font-size: 14.5px;
      color: var(--text-muted);
    }
    .nav-links {
      margin-top: 14px;
      display: flex;
      justify-content: center;
      gap: 16px;
      font-size: 13px;
    }
    .nav-links a {
      color: var(--gold);
      text-decoration: none;
      font-weight: 600;
    }
    .nav-links a:hover {
      text-decoration: underline;
    }
    .form-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 20px;
      padding: 36px;
      box-shadow: 0 20px 40px -15px rgba(0, 0, 0, 0.5);
      backdrop-filter: blur(12px);
    }
    .form-group {
      margin-bottom: 20px;
    }
    label {
      display: block;
      font-size: 12.5px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: var(--text-muted);
      margin-bottom: 8px;
    }
    label .req {
      color: #EF4444;
    }
    input, textarea {
      width: 100%;
      background: var(--input-bg);
      border: 1.5px solid var(--input-border);
      border-radius: 12px;
      padding: 13px 16px;
      font-size: 14.5px;
      color: #FFFFFF;
      outline: none;
      transition: all 0.2s;
    }
    input:focus, textarea:focus {
      border-color: var(--gold);
      box-shadow: 0 0 0 3px rgba(212, 175, 55, 0.2);
    }
    textarea {
      min-height: 120px;
      resize: vertical;
      line-height: 1.6;
    }
    .btn-submit {
      width: 100%;
      background: linear-gradient(135deg, #D4AF37 0%, #A38020 100%);
      color: #0A0F1D;
      font-size: 15px;
      font-weight: 800;
      letter-spacing: 0.5px;
      padding: 14px 20px;
      border: none;
      border-radius: 12px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      transition: all 0.2s;
      box-shadow: 0 4px 15px rgba(212, 175, 55, 0.25);
    }
    .btn-submit:hover:not(:disabled) {
      filter: brightness(1.1);
      transform: translateY(-1px);
    }
    .btn-submit:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }
    .banner {
      display: none;
      padding: 14px 18px;
      border-radius: 12px;
      font-size: 14px;
      margin-bottom: 22px;
      line-height: 1.5;
    }
    .banner.success {
      background: rgba(16, 185, 129, 0.15);
      border: 1px solid rgba(16, 185, 129, 0.4);
      color: #6EE7B7;
    }
    .banner.error {
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid rgba(239, 68, 68, 0.4);
      color: #FCA5A5;
    }
    .footer {
      text-align: center;
      margin-top: 32px;
      font-size: 12.5px;
      color: var(--text-muted);
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="badge">Inquiries & Support</div>
      <h1>Contact Us</h1>
      <p class="subtitle">NB Infra Projects LTD. · Official Communication Portal</p>
      <div class="nav-links">
        <a href="/login">← Back to Login</a>
        <span style="color: var(--card-border)">|</span>
        <a href="/privacypolicy">Privacy Policy</a>
      </div>
    </div>

    <div class="form-card">
      <div id="banner-success" class="banner success"></div>
      <div id="banner-error" class="banner error"></div>

      <form id="contact-form">
        <div class="form-group">
          <label for="input-name">Full Name <span class="req">*</span></label>
          <input type="text" id="input-name" required placeholder="Enter your full name" />
        </div>

        <div class="form-group">
          <label for="input-email">Email Address <span class="req">*</span></label>
          <input type="email" id="input-email" required placeholder="name@company.com" />
        </div>

        <div class="form-group">
          <label for="input-phone">Phone Number</label>
          <input type="tel" id="input-phone" placeholder="+91 98765 43210" />
        </div>

        <div class="form-group">
          <label for="input-subject">Subject <span class="req">*</span></label>
          <input type="text" id="input-subject" required placeholder="Subject of your inquiry" value="General Inquiry" />
        </div>

        <div class="form-group">
          <label for="input-message">Message <span class="req">*</span></label>
          <textarea id="input-message" required placeholder="Please write your message or inquiry here..."></textarea>
        </div>

        <button type="submit" id="btn-submit" class="btn-submit">
          <span>Send Message</span>
        </button>
      </form>
    </div>

    <div class="footer">
      © 2026 NB Infra Projects LTD. All rights reserved.
    </div>
  </div>

  <script>
    const form = document.getElementById('contact-form');
    const btn = document.getElementById('btn-submit');
    const successBanner = document.getElementById('banner-success');
    const errorBanner = document.getElementById('banner-error');

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      successBanner.style.display = 'none';
      errorBanner.style.display = 'none';

      const name = document.getElementById('input-name').value.trim();
      const email = document.getElementById('input-email').value.trim();
      const phone = document.getElementById('input-phone').value.trim();
      const subject = document.getElementById('input-subject').value.trim();
      const message = document.getElementById('input-message').value.trim();

      if (!name || !email || !message) {
        showError('Please fill in all required fields.');
        return;
      }

      btn.disabled = true;
      btn.innerHTML = '<span>Sending Message...</span>';

      try {
        const res = await fetch('/api/contactus', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name, email, phone, subject, message }),
        });

        const data = await res.json();
        if (!res.ok || !data.success) {
          throw new Error(data.error || 'Failed to deliver message. Please try again.');
        }

        successBanner.textContent = 'Thank you for reaching out! Your message has been sent to our IT team (it.nbdeveloper@gmail.com). We will get back to you shortly.';
        successBanner.style.display = 'block';
        form.reset();
        document.getElementById('input-subject').value = 'General Inquiry';
      } catch (err) {
        showError(err.message || 'An unexpected error occurred. Please try again.');
      } finally {
        btn.disabled = false;
        btn.innerHTML = '<span>Send Message</span>';
      }
    });

    function showError(msg) {
      errorBanner.textContent = msg;
      errorBanner.style.display = 'block';
    }
  </script>
</body>
</html>`;
