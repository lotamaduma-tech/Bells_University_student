import { useState, type FormEvent } from 'react';
import { Check, LoaderCircle, MessageSquareText, X } from 'lucide-react';
import { supabase } from './lib/supabase';

export default function FeedbackModal({ onClose, onSubmitted, initialCategory = 'suggestion' }: { onClose: () => void; onSubmitted: () => void; initialCategory?: 'suggestion'|'bug'|'experience'|'other' }) {
  const [category, setCategory] = useState(initialCategory);
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState(false);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (!supabase) { setError('Feedback is temporarily unavailable. Please try again later.'); return; }
    if (message.trim().length < 8) { setError('Please write at least 8 characters.'); return; }
    setBusy(true); setError('');
    try {
      const { data: { user }, error: userError } = await supabase.auth.getUser();
      if (userError) throw userError;
      if (!user) throw new Error('Please sign in again to send feedback.');
      const { error: insertError } = await supabase.from('bellsconnect_feedback').insert({
        user_id: user.id, category, message: message.trim()
      });
      if (insertError) throw insertError;
      setDone(true);
      onSubmitted();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not submit feedback. Please try again.');
    } finally { setBusy(false); }
  };

  return <div className="bc-modal-backdrop" onClick={onClose}>
    <section className="bc-modal bc-feedback-modal" role="dialog" aria-modal="true" aria-labelledby="bc-feedback-title" onClick={e => e.stopPropagation()}>
      <button className="bc-modal-close" onClick={onClose} aria-label="Close feedback"><X size={18}/></button>
      {done ? <div className="bc-feedback-success"><span><Check size={25}/></span><h2 id="bc-feedback-title">Feedback received.</h2><p>Thanks for helping improve BellsConnect. Your message has been saved privately for the developer to review.</p><button className="bc-btn primary" onClick={onClose}>Done</button></div> :
      <><span className="bc-feedback-icon"><MessageSquareText size={21}/></span><span className="bc-eyebrow">HELP BELLSCONNECT IMPROVE</span><h2 id="bc-feedback-title">Give the developer feedback</h2><p>Share an idea, report a bug, or tell us how the app feels to use.</p>
      <form className="bc-profile-form" onSubmit={submit}>
        <label>Feedback type<select value={category} onChange={e => setCategory(e.target.value as 'suggestion'|'bug'|'experience'|'other')}><option value="suggestion">Feature idea / suggestion</option><option value="bug">Report a bug</option><option value="experience">My experience using the app</option><option value="other">Other feedback</option></select></label>
        <label>Your message<textarea value={message} onChange={e => setMessage(e.target.value)} placeholder="Tell us what's working, what isn't, or what you'd love to see…" minLength={8} maxLength={3000} required /></label>
        <small className="bc-feedback-count">{message.length}/3000 characters. Feedback is visible only to authorized administrators.</small>
        {error && <p className="bc-feedback-error" role="alert">{error}</p>}
        <button className="bc-btn primary" disabled={busy || message.trim().length < 8}>{busy ? <><LoaderCircle size={16}/> Sending…</> : 'Send feedback'}</button>
      </form></>}
    </section>
  </div>;
}
