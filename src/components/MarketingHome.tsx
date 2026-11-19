import {useState} from 'react'
import './marketing.css'

export function MarketingHome(){
  const [menuOpen,setMenuOpen]=useState(false)

  function closeMenu(){setMenuOpen(false)}

  return <div className="marketing">
    <a className="marketing-skip" href="#marketing-main">Skip to content</a>
    <header className="marketing-header">
      <div className="marketing-wrap marketing-bar">
        <a className="marketing-logo" href="#home" aria-label="HangOut home">
          <img src="/hangout-logo.png" alt=""/>
        </a>
        <nav className="marketing-nav" aria-label="Main navigation">
          <button className="marketing-menu-button" type="button" aria-expanded={menuOpen} aria-controls="marketing-menu" onClick={()=>setMenuOpen(!menuOpen)}>Menu</button>
          <ul id="marketing-menu" className={menuOpen?'is-open':''}>
            <li><a href="#how-it-works" onClick={closeMenu}>How it works</a></li>
            <li><a href="#places" onClick={closeMenu}>Places</a></li>
            <li><a href="#safety" onClick={closeMenu}>Safety</a></li>
            <li><a className="marketing-button marketing-button-small" href="#signup" onClick={closeMenu}>Join free</a></li>
            <li><a className="marketing-login" href="#login" onClick={closeMenu}>Log in</a></li>
          </ul>
        </nav>
      </div>
    </header>

    <main id="marketing-main" className="marketing-wrap">
      <section id="home" className="marketing-hero" aria-labelledby="marketing-title">
        <div>
          <p className="marketing-eyebrow">A little more common ground</p>
          <h1 id="marketing-title">Find people who enjoy the same places you do.</h1>
          <p className="marketing-lede">Pin a few favorite cafés, parks, and neighborhood spots. HangOut helps you discover people who chose some of the same places.</p>
          <div className="marketing-actions">
            <a className="marketing-button" href="#signup">Create your free profile</a>
            <a className="marketing-button marketing-button-outline" href="#how-it-works">See how it works</a>
          </div>
          <p className="marketing-small">Start with places you choose to share. Meet at a public spot when you’re ready.</p>
        </div>
        <div className="marketing-hero-art">
          <img
            src="/marketing-hero-collage.jfif"
            alt="Collage of a neighborhood café, two hikers on a mountain trail, and a city skyline, with the phrases “Good People, Brighter Places” and “Same Interests, More Adventures.”"
          />
        </div>
      </section>

      <section className="marketing-section" aria-labelledby="why-title">
        <p className="marketing-eyebrow">Start with something in common</p>
        <h2 id="why-title">A good first hello can start with a familiar place.</h2>
        <div className="marketing-grid">
          <article className="marketing-card"><span className="marketing-card-mark" aria-hidden="true">01</span><h3>Common ground, built in</h3><p>Discover people who have also pinned a place you like, giving you an easy conversation starter.</p></article>
          <article className="marketing-card"><span className="marketing-card-mark" aria-hidden="true">02</span><h3>Your places, your choice</h3><p>Choose up to five hangouts that say something about how you like to spend your time.</p></article>
          <article className="marketing-card marketing-card-highlight"><span className="marketing-card-mark" aria-hidden="true">03</span><h3>Take it at your pace</h3><p>Chat with a match and suggest a shared public place for a meetup when you’re comfortable.</p></article>
        </div>
      </section>

      <section id="how-it-works" className="marketing-section" aria-labelledby="steps-title">
        <p className="marketing-eyebrow">Easy as one, two, three</p>
        <h2 id="steps-title">From favorite spot to a first hello.</h2>
        <ol className="marketing-steps">
          <li><span>1</span><div><h3>Create your account</h3><p>Sign up with your email and add a little about yourself.</p></div></li>
          <li><span>2</span><div><h3>Pin your hangouts</h3><p>Choose up to 5 places you enjoy visiting.</p></div></li>
          <li><span>3</span><div><h3>Discover and connect</h3><p>Like people who share your places. When the interest is mutual, start a conversation.</p></div></li>
        </ol>
      </section>

      <section id="places" className="marketing-band" aria-labelledby="places-title">
        <div>
          <p className="marketing-eyebrow">Your usual, your next favorite</p>
          <h2 id="places-title">Any place can be a starting point.</h2>
          <p>From a coffee shop or bookshop to a park or live music venue, pin the places you’re happy to share.</p>
          <ul className="marketing-chips" aria-label="Example hangout places">
            <li>Coffee shops</li><li>Parks</li><li>Bookshops</li><li>Food halls</li><li>Live music</li>
          </ul>
        </div>
        <a className="marketing-button" href="#signup">Pin your first place</a>
      </section>

      <section id="safety" className="marketing-section" aria-labelledby="safety-title">
        <p className="marketing-eyebrow">Comfort comes first</p>
        <h2 id="safety-title">Make new connections on your terms.</h2>
        <div className="marketing-grid">
          <article className="marketing-card"><h3>Choose what you share</h3><p>Discovery is based on places you choose to pin. Don’t add a place if you’re not comfortable sharing it.</p></article>
          <article className="marketing-card"><h3>Use block and report</h3><p>In the app, you can block or report someone from a conversation.</p></article>
          <article className="marketing-card"><h3>Meet thoughtfully</h3><p>If you decide to meet, choose a public place, arrange your own transport, and let someone you trust know.</p></article>
        </div>
      </section>

      <section className="marketing-cta" aria-labelledby="join-title">
        <div><p className="marketing-eyebrow">Your next hello starts here</p><h2 id="join-title">Find a little more common ground.</h2><p>Create an account and add the places you love.</p></div>
        <a className="marketing-button" href="#signup">Join HangOut</a>
      </section>
    </main>

    <footer className="marketing-footer">
      <div className="marketing-wrap marketing-footer-inner">
        <a className="marketing-logo" href="#home" aria-label="HangOut home"><img src="/hangout-logo.png" alt=""/></a>
        <p>Find people who share your interests and the places you love.</p>
        <nav aria-label="Footer navigation"><a href="#how-it-works">How it works</a><a href="#safety">Safety</a><a href="/privacy-policy.html">Privacy Policy</a><a href="/data-deletion.html">Data Deletion</a><a href="#signup">Sign up</a><a href="#login">Log in</a></nav>
        <small>Closed beta. Features and availability may change.</small>
      </div>
    </footer>
  </div>
}
