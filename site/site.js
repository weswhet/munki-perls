(function () {
  'use strict';

  var root = document.documentElement;
  var reducedMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var enhanced = (' ' + root.className + ' ').indexOf(' enhanced ') !== -1;

  function addClass(element, name) {
    if ((' ' + element.className + ' ').indexOf(' ' + name + ' ') === -1) {
      element.className += ' ' + name;
    }
  }

  if (enhanced && !reducedMotion) {
    addClass(root, 'motion-ready');
  }

  function copyText(button) {
    var target = document.getElementById(button.getAttribute('data-copy'));
    var original = button.innerHTML;
    function done() {
      button.innerHTML = 'Copied';
      window.setTimeout(function () { button.innerHTML = original; }, 1600);
    }
    function legacyCopy() {
      var area = document.createElement('textarea');
      area.value = target.textContent || target.innerText;
      area.style.position = 'absolute';
      area.style.left = '-9999px';
      document.body.appendChild(area);
      area.select();
      try { document.execCommand('copy'); done(); } catch (ignore) {}
      document.body.removeChild(area);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(target.textContent || target.innerText).then(done, legacyCopy);
    } else {
      legacyCopy();
    }
  }

  var buttons = document.querySelectorAll ? document.querySelectorAll('[data-copy]') : [];
  var i;
  for (i = 0; i < buttons.length; i += 1) {
    buttons[i].onclick = function () { copyText(this); };
  }

  if (!enhanced) { return; }

  var reveals = document.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in window) || reducedMotion) {
    for (i = 0; i < reveals.length; i += 1) { addClass(reveals[i], 'is-visible'); }
  } else {
    var observer = new IntersectionObserver(function (entries) {
      var j;
      for (j = 0; j < entries.length; j += 1) {
        if (entries[j].isIntersecting) {
          addClass(entries[j].target, 'is-visible');
          observer.unobserve(entries[j].target);
        }
      }
    }, { threshold: 0.12 });
    for (i = 0; i < reveals.length; i += 1) { observer.observe(reveals[i]); }
  }

  var art = document.querySelector('.hero-art');
  if (art && !reducedMotion) {
    window.addEventListener('mousemove', function (event) {
      var x = (event.clientX / window.innerWidth) - 0.5;
      var y = (event.clientY / window.innerHeight) - 0.5;
      art.style.setProperty('--art-y', (y * 10) + 'px');
      art.style.setProperty('--art-r', (x * 1.2) + 'deg');
    });
  }
}());
