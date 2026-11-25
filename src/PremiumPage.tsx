import { useEffect, useState } from 'react';
import { ArrowLeft, ArrowUpRight, BarChart3, BadgeCheck, Crown, Megaphone, Store, TrendingUp } from 'lucide-react';
import { supabase } from './lib/supabase';

type Subscription = { plan_code: string; billing_period: string; status: string; current_period_end: string | null };

export default function PremiumPage({ onBack }: { onBack: () => void }) {
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [isVendor, setIsVendor] = useState(false);
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [interested, setInterested] = useState(false);
  const [listingCount, setListingCount] = useState(0);
  const [viewCount, setViewCount] = useState(0);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    (async () => {
      if (!supabase) { setError('MARKIO is not connected to its marketplace database.'); setLoading(false); return; }
      try {
        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError) throw authError;
        if (!user) throw new Error('Please sign in again.');
        const [store, plan, interest, listings, views] = await Promise.all([
          supabase.from('seller_profiles').select('user_id').eq('user_id', user.id).eq('status', 'approved').maybeSingle(),
          supabase.from('vendor_subscriptions').select('plan_code,billing_period,status,current_period_end').eq('user_id', user.id).eq('status', 'active').order('created_at', { ascending: false }).limit(1).maybeSingle(),
          supabase.from('premium_interest').select('user_id').eq('user_id', user.id).maybeSingle(),
          supabase.from('marketplace_listings').select('id', { count: 'exact', head: true }).eq('seller_id', user.id).eq('status', 'approved'),
          supabase.from('listing_views').select('id', { count: 'exact', head: true }).eq('seller_id', user.id)
        ]);
        if (store.error) throw store.error;
        if (plan.error) throw plan.error;
        if (interest.error) throw interest.error;
        if (listings.error) throw listings.error;
        if (views.error) throw views.error;
        if (!active) return;
        setIsVendor(!!store.data);
        setSubscription(plan.data as Subscription | null);
        setInterested(!!interest.data);
        setListingCount(listings.count || 0);
        setViewCount(views.count || 0);
      } catch (err) {
        if (active) setError(err instanceof Error ? err.message : 'Could not load Premium details.');
      } finally { if (active) setLoading(false); }
    })();
    return () => { active = false; };
  }, []);

  const joinInterestList = async () => {
    if (!supabase || busy) return;
    setBusy(true); setError(''); setMessage('');
    try {
      const { data: { user }, error: authError } = await supabase.auth.getUser();
      if (authError) throw authError;
      if (!user) throw new Error('Please sign in again.');
      const { error: saveError } = await supabase.from('premium_interest').upsert(
        { user_id: user.id, source: 'vendor-dashboard' },
        { onConflict: 'user_id', ignoreDuplicates: true }
      );
      if (saveError) throw saveError;
      setInterested(true);
      setMessage('You are on the MARKIO Premium early-access list.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save your interest. Please try again.');
    } finally { setBusy(false); }
  };

  return <section className="premium-page">
    <button className="market-back-link" onClick={onBack}><ArrowLeft size={16}/> Back to marketplace</button>
    <div className="premium-hero">
      <span className="premium-eyebrow"><Crown size={15}/> MARKIO FOR BUSINESS</span>
      <div className="premium-hero-grid">
        <div>
          <h1>Give your student business <em>room to grow.</em></h1>
          <p>Premium is designed for vendors who want clearer performance insights, stronger storefronts and more ways to reach buyers across their university community.</p>
          <div className="premium-hero-actions">
            {subscription ? <span className="premium-active-pill"><BadgeCheck size={16}/> Premium active</span> :
              <button className="market-primary" disabled={!isVendor || interested || busy || loading} onClick={joinInterestList}>
                {busy ? 'Saving…' : interested ? 'You’re on the early-access list' : 'Get early access'} <ArrowUpRight size={16}/>
              </button>}
            <span className="premium-note">No charge is taken on this page.</span>
          </div>
        </div>
        <div className="premium-preview-card">
          <div className="premium-preview-top"><span>VENDOR OVERVIEW</span><Crown size={17}/></div>
          <div className="premium-preview-metrics"><div><small>ACTIVE LISTINGS</small><strong>{loading ? '—' : listingCount}</strong></div><div><small>PRODUCT VIEWS</small><strong>{loading ? '—' : viewCount}</strong></div></div>
          <div className="premium-preview-chart">{Array.from({length:12},(_,i)=><span key={i}/>)}</div>
          <small className="premium-preview-caption">A preview of the business insights planned for Premium</small>
        </div>
      </div>
    </div>
    {!loading && !isVendor && <div className="premium-callout"><Store size={19}/><div><strong>Premium is for approved student vendors.</strong><p>Apply for a storefront first. Buyers can continue using the marketplace for free.</p></div></div>}
    {subscription && <div className="premium-callout premium-callout-active"><BadgeCheck size={19}/><div><strong>Your Premium subscription is active.</strong><p>{subscription.plan_code} · {subscription.billing_period}{subscription.current_period_end ? ' · Ends ' + new Date(subscription.current_period_end).toLocaleDateString() : ''}</p></div></div>}
    <div className="premium-section-heading"><span className="premium-eyebrow">WHAT PREMIUM ADDS</span><h2>More control over your business.</h2><p>Core marketplace access stays free. Premium adds optional tools for vendors.</p></div>
    <div className="premium-feature-grid">
      <article><span><BarChart3 size={20}/></span><h3>Advanced analytics</h3><p>Understand listing views, customer interest and which products attract attention.</p></article>
      <article><span><Megaphone size={20}/></span><h3>Promoted listings</h3><p>Give selected products extra visibility through clearly labelled sponsored placements.</p></article>
      <article><span><Store size={20}/></span><h3>Enhanced storefront</h3><p>Make your business page more recognisable with additional layout and showcase options.</p></article>
      <article><span><TrendingUp size={20}/></span><h3>More room to list</h3><p>Higher active-listing limits and more tools as your business grows.</p></article>
    </div>
    <div className="premium-plan-card"><div><span className="premium-eyebrow">OPTIONAL VENDOR SUBSCRIPTION</span><h2>MARKIO Premium</h2><p>Monthly and annual plans will be announced before paid subscriptions open.</p></div><div className="premium-plan-status"><strong>{subscription ? 'Your plan is active' : 'Early access'}</strong><small>{subscription ? 'Subscription status is managed securely.' : 'Payment checkout is not enabled yet.'}</small></div></div>
    {error && <div className="market-alert error" role="alert">{error}</div>}
    {message && <div className="market-alert" role="status">{message}</div>}
  </section>;
}