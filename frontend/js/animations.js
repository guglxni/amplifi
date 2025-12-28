/**
 * ReactBits Style Animations Library
 * Features: Spotlight Card, Tilt Effect, Fade In, Shiny Text
 */

const Animations = {
    init() {
        this.initSpotlight();
        this.initTilt();
        this.initFadeIn();
    },

    // Spotlight Effect: Tracks mouse to create a radial gradient glow
    initSpotlight() {
        const cards = document.querySelectorAll('.card, .spotlight-target');

        cards.forEach(card => {
            card.addEventListener('mousemove', (e) => {
                const rect = card.getBoundingClientRect();
                const x = e.clientX - rect.left;
                const y = e.clientY - rect.top;

                card.style.setProperty('--mouse-x', `${x}px`);
                card.style.setProperty('--mouse-y', `${y}px`);
                card.style.setProperty('--spotlight-opacity', '1');
            });

            card.addEventListener('mouseleave', () => {
                card.style.setProperty('--spotlight-opacity', '0');
            });
        });
    },

    // 3D Tilt Effect
    initTilt() {
        const tiltCards = document.querySelectorAll('.card-tilt');

        tiltCards.forEach(card => {
            card.addEventListener('mousemove', (e) => {
                const rect = card.getBoundingClientRect();
                const x = e.clientX - rect.left;
                const y = e.clientY - rect.top;

                const centerX = rect.width / 2;
                const centerY = rect.height / 2;

                const rotateX = ((y - centerY) / centerY) * -5; // Max -5deg rotation
                const rotateY = ((x - centerX) / centerX) * 5;  // Max 5deg rotation

                card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.02, 1.02, 1.02)`;
            });

            card.addEventListener('mouseleave', () => {
                card.style.transform = 'perspective(1000px) rotateX(0) rotateY(0) scale3d(1, 1, 1)';
            });
        });
    },

    // Staggered Fade In for Grid Items
    initFadeIn() {
        const elements = document.querySelectorAll('.dashboard-grid > *');
        elements.forEach((el, index) => {
            el.style.opacity = '0';
            el.style.transform = 'translateY(20px)';
            setTimeout(() => {
                el.style.transition = 'all 0.6s cubic-bezier(0.16, 1, 0.3, 1)';
                el.style.opacity = '1';
                el.style.transform = 'translateY(0)';
            }, index * 100);
        });
    }
};

document.addEventListener('DOMContentLoaded', () => {
    Animations.init();
});
