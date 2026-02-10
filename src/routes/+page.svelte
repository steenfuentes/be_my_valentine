<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import {
		PUBLIC_RECIPIENT_NAME,
		PUBLIC_INITIALS,
		PUBLIC_PAGE_TITLE,
		PUBLIC_CELEBRATION_MESSAGE,
		PUBLIC_AUTOMATON_TITLE
	} from '$env/static/public';
	import tooltipConfig from '$lib/config/tooltips.json';

	// ── Initials Validation ──

	/**
	 * Result of validating the initials input string.
	 */
	interface InitialsValidation {
		/** Whether the input matches the expected format */
		isValid: boolean;
		/** Normalized initials string (e.g., "B + S") or fallback "? + ?" */
		formatted: string;
		/** Error message if validation failed */
		error?: string;
	}

	/**
	 * Validates that initials follow the format "X + Y" where X and Y are single letters.
	 *
	 * @param input - Raw initials string from environment variable
	 * @returns Validation result with formatted string or error
	 *
	 * @example
	 * validateInitials("b + s")  // { isValid: true, formatted: "B + S" }
	 * validateInitials("Bob")    // { isValid: false, formatted: "? + ?", error: "..." }
	 */
	function validateInitials(input: string): InitialsValidation {
		const trimmed = input.trim();

		if (!trimmed) {
			return { isValid: false, formatted: '? + ?', error: 'Initials cannot be empty' };
		}

		const match = trimmed.match(/^([A-Za-z])\s*\+\s*([A-Za-z])$/);

		if (!match) {
			return {
				isValid: false,
				formatted: '? + ?',
				error: `Invalid initials format: "${trimmed}". Expected format: "X + Y" where X and Y are single letters`
			};
		}

		const [, first, second] = match;
		return {
			isValid: true,
			formatted: `${first.toUpperCase()} + ${second.toUpperCase()}`
		};
	}

	const initialsValidation = validateInitials(PUBLIC_INITIALS);
	const validatedInitials = initialsValidation.formatted;

	if (!initialsValidation.isValid) {
		console.warn(`[Valentine] ${initialsValidation.error}`);
	}

	// ── Tooltip Rotation ──

	/** Valid tooltip categories corresponding to app phases with back buttons */
	type TooltipCategory = 'celebration' | 'automaton';

	/**
	 * Manages rotation through a set of tooltip messages without repetition.
	 * Messages are randomly selected and won't repeat until all have been shown.
	 *
	 * @example
	 * const rotator = new TooltipRotator(["msg1", "msg2", "msg3"]);
	 * rotator.current;  // Random initial message
	 * rotator.next();   // Different message, won't repeat until all shown
	 */
	class TooltipRotator {
		/** Complete list of available messages */
		private messages: string[];
		/** Messages not yet shown in current cycle */
		private remaining: string[];
		/** Currently displayed message */
		current: string;

		/**
		 * @param messages - Array of tooltip messages to rotate through
		 */
		constructor(messages: string[]) {
			this.messages = [...messages];
			this.remaining = [];
			this.current = this.next();
		}

		/**
		 * Selects the next random message from remaining pool.
		 * Refills the pool when exhausted to start a new cycle.
		 *
		 * @returns The next message to display
		 */
		next(): string {
			if (this.remaining.length === 0) {
				this.remaining = [...this.messages];
			}
			const index = Math.floor(Math.random() * this.remaining.length);
			this.current = this.remaining.splice(index, 1)[0];
			return this.current;
		}
	}

	const tooltipRotators: Record<TooltipCategory, TooltipRotator> = {
		celebration: new TooltipRotator(tooltipConfig.backButton.celebration),
		automaton: new TooltipRotator(tooltipConfig.backButton.automaton)
	};

	let celebrationTooltip = $state(tooltipRotators.celebration.current);
	let automatonTooltip = $state(tooltipRotators.automaton.current);

	/** Delay before rotating tooltip text, allows CSS fade-out to complete */
	const TOOLTIP_FADE_DURATION = 250;

	/** Rotates celebration tooltip after fade-out delay */
	function rotateCelebrationTooltip() {
		setTimeout(() => {
			celebrationTooltip = tooltipRotators.celebration.next();
		}, TOOLTIP_FADE_DURATION);
	}

	/** Rotates automaton tooltip after fade-out delay */
	function rotateAutomatonTooltip() {
		setTimeout(() => {
			automatonTooltip = tooltipRotators.automaton.next();
		}, TOOLTIP_FADE_DURATION);
	}

	// ── State machine ──
	type Phase = 'question' | 'celebration' | 'automaton';
	let phase: Phase = $state('question');

	// ── Phase 1: Question ──
	let noBtn: HTMLButtonElement | undefined = $state();
	let questionContent: HTMLDivElement | undefined = $state();
	let noDodgeCount = $state(0);
	const noTexts = [
		'No',
		'Are you sure?',
		'Really sure?',
		'Think again!',
		'Pretty please?',
		'Last chance!',
		"Don't do this...",
		"You're breaking my heart!",
		':(('
	];

	/** Bounding box coordinates for collision detection */
	interface Rect {
		left: number;
		right: number;
		top: number;
		bottom: number;
	}

	/** Checks if two rectangles intersect using AABB collision detection */
	function rectsOverlap(a: Rect, b: Rect): boolean {
		return a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top;
	}

	/**
	 * Generates a random viewport position that doesn't overlap the exclusion zone.
	 * Falls back to top-left corner after max attempts to prevent infinite loops.
	 */
	function generateSafePosition(btnWidth: number, btnHeight: number, exclusionZone: Rect): { x: number; y: number } {
		const vw = window.innerWidth;
		const vh = window.innerHeight;
		const pad = 80;
		const maxAttempts = 50;

		for (let i = 0; i < maxAttempts; i++) {
			const x = pad + Math.random() * (vw - pad * 2 - btnWidth);
			const y = pad + Math.random() * (vh - pad * 2 - btnHeight);

			const btnRect: Rect = {
				left: x,
				right: x + btnWidth,
				top: y,
				bottom: y + btnHeight
			};

			if (!rectsOverlap(btnRect, exclusionZone)) {
				return { x, y };
			}
		}

		return { x: pad, y: pad };
	}

	/**
	 * Moves the "No" button to a random position away from center content.
	 * Button shrinks and speeds up with each dodge attempt.
	 */
	function dodgeNo() {
		noDodgeCount++;
		if (!noBtn || !questionContent) return;

		const contentRect = questionContent.getBoundingClientRect();
		const btnRect = noBtn.getBoundingClientRect();
		const margin = 20;

		const exclusionZone: Rect = {
			left: contentRect.left - margin,
			right: contentRect.right + margin,
			top: contentRect.top - margin,
			bottom: contentRect.bottom + margin
		};

		const { x, y } = generateSafePosition(btnRect.width, btnRect.height, exclusionZone);

		noBtn.style.position = 'fixed';
		noBtn.style.left = `${x}px`;
		noBtn.style.top = `${y}px`;
		noBtn.style.transform = `scale(${Math.max(0.4, 1 - noDodgeCount * 0.08)})`;
		noBtn.style.transition = `all ${Math.max(0.05, 0.25 - noDodgeCount * 0.02)}s cubic-bezier(0.34, 1.56, 0.64, 1)`;
	}

	/** Transitions from question phase to celebration */
	function sayYes() {
		phase = 'celebration';
		startCelebration();
	}

	/**
	 * Navigates to the previous phase, cleaning up animations and state.
	 * celebration → question (resets No button), automaton → celebration
	 */
	function goBack() {
		if (phase === 'celebration') {
			cancelAnimationFrame(celebAnimId);
			if (celebTransitionTimer) clearTimeout(celebTransitionTimer);
			celebParticles = [];
			phase = 'question';
			noDodgeCount = 0;
			if (noBtn) {
				noBtn.style.position = '';
				noBtn.style.left = '';
				noBtn.style.top = '';
				noBtn.style.transform = '';
			}
		} else if (phase === 'automaton') {
			cancelAnimationFrame(autoAnimId);
			autoRunning = false;
			phase = 'celebration';
			startCelebration();
		}
	}

	// ── Phase 2: Celebration ──
	// Particle system for hearts and confetti animation

	let celebCanvas: HTMLCanvasElement | undefined = $state();
	let celebCtx: CanvasRenderingContext2D | null = null;
	let celebAnimId = 0;

	/** Physics and visual properties for a celebration particle */
	interface Particle {
		x: number;
		y: number;
		vx: number;
		vy: number;
		size: number;
		color: string;
		alpha: number;
		decay: number;
		rotation: number;
		rotSpeed: number;
		type: 'heart' | 'confetti';
	}

	let celebParticles: Particle[] = [];
	let celebTransitionTimer: ReturnType<typeof setTimeout> | null = null;

	/** Initializes particle system and auto-transitions to automaton after 3.5s */
	function startCelebration() {
		requestAnimationFrame(() => {
			if (!celebCanvas) return;
			celebCanvas.width = window.innerWidth;
			celebCanvas.height = window.innerHeight;
			celebCtx = celebCanvas.getContext('2d');

			for (let i = 0; i < 120; i++) {
				celebParticles.push(makeParticle(window.innerWidth / 2, window.innerHeight / 2));
			}
			for (let i = 0; i < 60; i++) {
				const p = makeParticle(Math.random() * window.innerWidth, -50);
				p.vy = Math.abs(p.vy) * 0.5 + 1;
				p.vx *= 0.3;
				celebParticles.push(p);
			}
			animateCeleb();

			celebTransitionTimer = setTimeout(() => {
				if (phase === 'celebration') {
					enterAutomaton();
				}
			}, 3500);
		});
	}

	const heartColors = ['#9B1B30', '#C0364F', '#E05A7A', '#E8A0B4', '#D4456A', '#FF6B8A'];
	const confettiColors = ['#C9A96E', '#E8A0B4', '#9B1B30', '#FFD700', '#FF69B4', '#FF1493'];

	function makeParticle(cx: number, cy: number): Particle {
		const isHeart = Math.random() > 0.4;
		return {
			x: cx, y: cy,
			vx: (Math.random() - 0.5) * 16,
			vy: (Math.random() - 0.5) * 16 - 4,
			size: isHeart ? 8 + Math.random() * 18 : 4 + Math.random() * 8,
			color: isHeart
				? heartColors[Math.floor(Math.random() * heartColors.length)]
				: confettiColors[Math.floor(Math.random() * confettiColors.length)],
			alpha: 1,
			decay: 0.003 + Math.random() * 0.006,
			rotation: Math.random() * Math.PI * 2,
			rotSpeed: (Math.random() - 0.5) * 0.2,
			type: isHeart ? 'heart' : 'confetti'
		};
	}

	/** Draws a heart shape using bezier curves at the specified position */
	function drawHeart(ctx: CanvasRenderingContext2D, x: number, y: number, size: number) {
		ctx.beginPath();
		const s = size / 2;
		ctx.moveTo(x, y + s * 0.3);
		ctx.bezierCurveTo(x, y - s * 0.5, x - s, y - s * 0.5, x - s, y + s * 0.1);
		ctx.bezierCurveTo(x - s, y + s * 0.6, x, y + s, x, y + s);
		ctx.bezierCurveTo(x, y + s, x + s, y + s * 0.6, x + s, y + s * 0.1);
		ctx.bezierCurveTo(x + s, y - s * 0.5, x, y - s * 0.5, x, y + s * 0.3);
		ctx.closePath();
		ctx.fill();
	}

	/** Animation loop for celebration particles with gravity and fade-out */
	function animateCeleb() {
		if (!celebCtx || !celebCanvas) return;
		celebCtx.clearRect(0, 0, celebCanvas.width, celebCanvas.height);

		for (let i = celebParticles.length - 1; i >= 0; i--) {
			const p = celebParticles[i];
			p.x += p.vx;
			p.y += p.vy;
			p.vy += 0.12;
			p.vx *= 0.99;
			p.alpha -= p.decay;
			p.rotation += p.rotSpeed;

			if (p.alpha <= 0) {
				celebParticles.splice(i, 1);
				continue;
			}

			celebCtx.save();
			celebCtx.translate(p.x, p.y);
			celebCtx.rotate(p.rotation);
			celebCtx.globalAlpha = p.alpha;
			celebCtx.fillStyle = p.color;

			if (p.type === 'heart') {
				drawHeart(celebCtx, 0, 0, p.size);
			} else {
				celebCtx.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2);
			}
			celebCtx.restore();
		}

		celebAnimId = requestAnimationFrame(animateCeleb);
	}

	/** Cleans up celebration and transitions to automaton phase */
	function enterAutomaton() {
		cancelAnimationFrame(celebAnimId);
		if (celebTransitionTimer) clearTimeout(celebTransitionTimer);
		celebParticles = [];
		phase = 'automaton';
		requestAnimationFrame(() => initAutomaton());
	}

	// ── Phase 3: Heart Cellular Automaton ──
	// Conway's Game of Life variant with heart-shaped initial state

	let autoCanvas: HTMLCanvasElement | undefined = $state();
	let autoCtx: CanvasRenderingContext2D | null = null;
	let autoAnimId = 0;
	let autoRunning = $state(true);
	let generation = $state(0);
	let frameCount = 0;

	/** Animation frames between each automaton generation step */
	const FRAMES_PER_STEP = 10;

	/** Size in pixels of each cell in the automaton grid */
	const CELL = 6;
	let cols = 0;
	let rows = 0;
	/** Current cell states (0 = dead, 1 = alive) */
	let grid: Uint8Array;
	/** How many generations each cell has been alive (for color aging) */
	let ages: Uint16Array;
	/** Buffer for computing next generation */
	let nextGrid: Uint8Array;
	/** Cells where initials are displayed (excluded from simulation) */
	let initialsMask: Uint8Array;

	/** Tests if a point is inside a heart shape using the implicit equation */
	function isInsideHeart(px: number, py: number, cx: number, cy: number, scale: number): boolean {
		const x = (px - cx) / scale;
		const y = -(py - cy) / scale;
		const a = x * x + y * y - 1;
		return a * a * a - x * x * y * y * y <= 0;
	}

	function initAutomaton() {
		if (!autoCanvas) return;
		autoCanvas.width = window.innerWidth;
		autoCanvas.height = window.innerHeight;
		autoCtx = autoCanvas.getContext('2d');

		cols = Math.floor(autoCanvas.width / CELL);
		rows = Math.floor(autoCanvas.height / CELL);
		grid = new Uint8Array(cols * rows);
		ages = new Uint16Array(cols * rows);
		nextGrid = new Uint8Array(cols * rows);
		initialsMask = new Uint8Array(cols * rows);

		computeInitialsMask();

		const cx = cols / 2;
		const cy = rows / 2;
		const heartScale = Math.min(cols, rows) * 0.28;

		for (let r = 0; r < rows; r++) {
			for (let c = 0; c < cols; c++) {
				const idx = r * cols + c;
				if (initialsMask[idx] === 0 && isInsideHeart(c, r, cx, cy, heartScale) && Math.random() < 0.6) {
					grid[idx] = 1;
					ages[idx] = 1;
				}
			}
		}

		generation = 0;
		frameCount = 0;
		autoRunning = false;

		renderAutomaton();

		setTimeout(() => {
			autoRunning = true;
			tickAutomaton();
		}, 2000);
	}

	/** Counts live neighbors for a cell (toroidal wrap at edges) */
	function countNeighbors(g: Uint8Array, c: number, r: number): number {
		let count = 0;
		for (let dr = -1; dr <= 1; dr++) {
			for (let dc = -1; dc <= 1; dc++) {
				if (dr === 0 && dc === 0) continue;
				const nr = (r + dr + rows) % rows;
				const nc = (c + dc + cols) % cols;
				count += g[nr * cols + nc];
			}
		}
		return count;
	}

	/** Advances simulation by one generation using Conway's Game of Life rules */
	function stepAutomaton() {
		nextGrid.fill(0);
		for (let r = 0; r < rows; r++) {
			for (let c = 0; c < cols; c++) {
				const idx = r * cols + c;
				const n = countNeighbors(grid, c, r);
				const alive = grid[idx];
				if (alive && (n === 2 || n === 3)) {
					nextGrid[idx] = 1;
					ages[idx]++;
				} else if (!alive && n === 3) {
					nextGrid[idx] = 1;
					ages[idx] = 1;
				} else {
					nextGrid[idx] = 0;
				}
			}
		}
		[grid, nextGrid] = [nextGrid, grid];
		generation++;
	}

	/** Maps cell age to color, older cells appear darker */
	function cellColor(age: number): string {
		if (age < 3) return '#FF1A4B';
		if (age < 8) return '#C0364F';
		if (age < 20) return '#9B1B30';
		if (age < 50) return '#7A1526';
		return '#5A101D';
	}

	/** Renders current grid state with initials overlay and cell aging colors */
	function renderAutomaton() {
		if (!autoCtx || !autoCanvas) return;
		autoCtx.fillStyle = '#0A0506';
		autoCtx.fillRect(0, 0, autoCanvas.width, autoCanvas.height);

		for (let r = 0; r < rows; r++) {
			for (let c = 0; c < cols; c++) {
				const idx = r * cols + c;
				if (initialsMask[idx] === 1) {
					autoCtx.fillStyle = '#C9A96E';
					autoCtx.fillRect(c * CELL, r * CELL, CELL - 1, CELL - 1);
				} else if (grid[idx] === 1) {
					autoCtx.fillStyle = cellColor(ages[idx]);
					autoCtx.fillRect(c * CELL, r * CELL, CELL - 1, CELL - 1);
				} else if (ages[idx] > 0) {
					autoCtx.fillStyle = `rgba(155, 27, 48, ${Math.min(0.15, ages[idx] * 0.01)})`;
					autoCtx.fillRect(c * CELL, r * CELL, CELL - 1, CELL - 1);
				}
			}
		}
	}

	/** Renders initials to offscreen canvas and samples to create grid mask */
	function computeInitialsMask() {
		if (!autoCanvas) return;

		const offscreen = document.createElement('canvas');
		offscreen.width = autoCanvas.width;
		offscreen.height = autoCanvas.height;
		const ctx = offscreen.getContext('2d')!;

		ctx.font = '900 200px "Playfair Display", Georgia, serif';
		ctx.textAlign = 'center';
		ctx.textBaseline = 'middle';
		ctx.fillStyle = 'white';
		ctx.letterSpacing = '-15px';
		ctx.fillText(validatedInitials, autoCanvas.width / 2, autoCanvas.height / 2);

		const imageData = ctx.getImageData(0, 0, offscreen.width, offscreen.height);
		const pixels = imageData.data;

		for (let r = 0; r < rows; r++) {
			for (let c = 0; c < cols; c++) {
				const px = c * CELL + Math.floor(CELL / 2);
				const py = r * CELL + Math.floor(CELL / 2);
				const pixelIdx = (py * offscreen.width + px) * 4;

				if (pixels[pixelIdx] > 128) {
					initialsMask[r * cols + c] = 1;
				}
			}
		}
	}

	/** Main animation loop, throttles generation steps by FRAMES_PER_STEP */
	function tickAutomaton() {
		if (!autoRunning) return;
		frameCount++;
		if (frameCount >= FRAMES_PER_STEP) {
			stepAutomaton();
			frameCount = 0;
		}
		renderAutomaton();
		autoAnimId = requestAnimationFrame(tickAutomaton);
	}

	/** Spawns a heart-shaped cluster of live cells at click position */
	function handleAutoClick(e: MouseEvent) {
		if (!autoCanvas) return;
		const rect = autoCanvas.getBoundingClientRect();
		const mx = e.clientX - rect.left;
		const my = e.clientY - rect.top;
		const cc = Math.floor(mx / CELL);
		const cr = Math.floor(my / CELL);

		const radius = 8;
		for (let dr = -radius; dr <= radius; dr++) {
			for (let dc = -radius; dc <= radius; dc++) {
				const nr = (cr + dr + rows) % rows;
				const nc = (cc + dc + cols) % cols;
				if (isInsideHeart(dc, dr, 0, 0, radius * 0.8) && Math.random() < 0.7) {
					grid[nr * cols + nc] = 1;
					ages[nr * cols + nc] = 1;
				}
			}
		}

		if (!autoRunning) renderAutomaton();
	}

	function toggleRunning() {
		autoRunning = !autoRunning;
		if (autoRunning) tickAutomaton();
	}

	function resetAutomaton() {
		cancelAnimationFrame(autoAnimId);
		initAutomaton();
	}

	onDestroy(() => {
		if (typeof window !== 'undefined') {
			cancelAnimationFrame(celebAnimId);
			cancelAnimationFrame(autoAnimId);
			if (celebTransitionTimer) clearTimeout(celebTransitionTimer);
		}
	});
</script>

<svelte:head>
	<title>{PUBLIC_PAGE_TITLE}</title>
	<link rel="preconnect" href="https://fonts.googleapis.com" />
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
	<link
		href="https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,700;1,400&family=Crimson+Pro:wght@300;400;600&display=swap"
		rel="stylesheet"
	/>
</svelte:head>

{#if phase === 'question'}
	<div class="scene question-scene">
		<div class="floating-hearts-bg" aria-hidden="true">
			{#each Array(15) as _, i}
				<span class="bg-heart" style="--i:{i}; --x:{10 + Math.random() * 80}; --d:{5 + Math.random() * 12}s; --s:{0.4 + Math.random() * 0.8}">&#10084;</span>
			{/each}
		</div>
		<div class="question-content" bind:this={questionContent}>
			<p class="greeting">Hi, {PUBLIC_RECIPIENT_NAME}...</p>
			<h1 class="question-title">Will you be my<br /><span class="accent">Valentine?</span></h1>
			<div class="button-row">
				<button class="btn btn-yes" onclick={sayYes}>Yes!</button>
			</div>
			<button
				class="btn btn-no"
				bind:this={noBtn}
				onmouseenter={dodgeNo}
				ontouchstart={dodgeNo}
				onclick={dodgeNo}
			>
				{noTexts[Math.min(noDodgeCount, noTexts.length - 1)]}
			</button>
		</div>
	</div>
{/if}

{#if phase === 'celebration'}
	<div class="scene celeb-scene">
		<canvas bind:this={celebCanvas} class="celeb-canvas"></canvas>
		<button class="btn-back" onclick={goBack} onmouseleave={rotateCelebrationTooltip} aria-label="Go back">
			<span class="back-tooltip">{celebrationTooltip}</span>
			&larr;
		</button>
		<div class="celeb-content">
			<div class="celeb-heart-icon">&#10084;</div>
			<h1 class="celeb-title">Yay!</h1>
			<p class="celeb-sub">{PUBLIC_CELEBRATION_MESSAGE}</p>
		</div>
	</div>
{/if}

{#if phase === 'automaton'}
	<div class="scene auto-scene">
		<canvas
			bind:this={autoCanvas}
			class="auto-canvas"
			onclick={handleAutoClick}
		></canvas>
		<button class="btn-back" onclick={goBack} onmouseleave={rotateAutomatonTooltip} aria-label="Go back">
			<span class="back-tooltip">{automatonTooltip}</span>
			&larr;
		</button>
		<div class="auto-hud">
			<div class="auto-hud-title">{PUBLIC_AUTOMATON_TITLE}</div>
			<div class="auto-hud-gen">Generation {generation}</div>
			<div class="auto-hud-hint">Click anywhere to seed hearts</div>
			<div class="auto-controls">
				<button class="hud-btn" onclick={toggleRunning}>{autoRunning ? 'Pause' : 'Play'}</button>
				<button class="hud-btn" onclick={resetAutomaton}>Reset</button>
			</div>
		</div>
	</div>
{/if}

<style>
	:global(body) {
		margin: 0;
		padding: 0;
		overflow: hidden;
		background: #0A0506;
		font-family: 'Crimson Pro', Georgia, serif;
	}

	.scene {
		position: fixed;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.question-scene {
		background: radial-gradient(ellipse at 50% 40%, #1F0A10 0%, #0A0506 70%);
	}

	.floating-hearts-bg {
		position: absolute;
		inset: 0;
		overflow: hidden;
		pointer-events: none;
	}

	.bg-heart {
		position: absolute;
		left: calc(var(--x) * 1%);
		bottom: -40px;
		font-size: calc(var(--s) * 2rem);
		color: rgba(155, 27, 48, 0.15);
		animation: floatUp var(--d) ease-in-out infinite;
		animation-delay: calc(var(--i) * -1.3s);
	}

	@keyframes floatUp {
		0% { transform: translateY(0) rotate(0deg); opacity: 0; }
		10% { opacity: 1; }
		90% { opacity: 1; }
		100% { transform: translateY(-110vh) rotate(25deg); opacity: 0; }
	}

	.question-content {
		text-align: center;
		z-index: 2;
		animation: fadeScaleIn 0.8s ease-out;
	}

	@keyframes fadeScaleIn {
		from { opacity: 0; transform: scale(0.9); }
		to { opacity: 1; transform: scale(1); }
	}

	.greeting {
		font-family: 'Playfair Display', Georgia, serif;
		font-size: clamp(1.4rem, 3vw, 2rem);
		color: #B08A94;
		margin: 0 0 1rem;
		font-style: italic;
	}

	.question-title {
		font-family: 'Playfair Display', Georgia, serif;
		font-weight: 400;
		font-size: clamp(2.2rem, 6vw, 4.5rem);
		color: #E8D0D5;
		line-height: 1.2;
		margin: 0 0 2.5rem;
		letter-spacing: -0.01em;
	}

	.accent {
		font-style: italic;
		font-weight: 700;
		color: #E05A7A;
		font-size: 1.25em;
	}

	.button-row {
		display: flex;
		justify-content: center;
		align-items: center;
		margin-bottom: 1.5rem;
	}

	.btn {
		font-family: 'Crimson Pro', Georgia, serif;
		border: none;
		cursor: pointer;
		border-radius: 999px;
		transition: all 0.2s ease;
		font-weight: 600;
	}

	.btn-yes {
		background: #9B1B30;
		color: #FFF5F0;
		font-size: 1.6rem;
		padding: 1rem 3.5rem;
		box-shadow: 0 0 40px rgba(155, 27, 48, 0.4), 0 4px 20px rgba(0, 0, 0, 0.3);
	}

	.btn-yes:hover {
		background: #C0364F;
		transform: scale(1.08);
		box-shadow: 0 0 60px rgba(192, 54, 79, 0.6), 0 4px 30px rgba(0, 0, 0, 0.3);
	}

	.btn-no {
		background: transparent;
		color: #6A5A5E;
		font-size: 1.1rem;
		padding: 0.7rem 2rem;
		border: 1px solid #3A2A2E;
		z-index: 100;
	}

	.btn-no:hover {
		border-color: #5A4A4E;
		color: #8A7A7E;
	}

	.celeb-scene {
		background: radial-gradient(ellipse at 50% 50%, #1F0A10 0%, #0A0506 70%);
	}

	.celeb-canvas {
		position: absolute;
		inset: 0;
		pointer-events: none;
	}

	.celeb-content {
		text-align: center;
		z-index: 2;
		animation: celebPop 0.6s cubic-bezier(0.34, 1.56, 0.64, 1);
	}

	@keyframes celebPop {
		from { opacity: 0; transform: scale(0.5); }
		to { opacity: 1; transform: scale(1); }
	}

	.celeb-heart-icon {
		font-size: 5rem;
		color: #E05A7A;
		animation: heartPulse 0.8s ease-in-out infinite alternate;
		margin-bottom: 0.5rem;
	}

	@keyframes heartPulse {
		from { transform: scale(1); }
		to { transform: scale(1.15); }
	}

	.celeb-title {
		font-family: 'Playfair Display', Georgia, serif;
		font-size: clamp(3rem, 8vw, 6rem);
		color: #FFF5F0;
		margin: 0;
		font-weight: 700;
	}

	.celeb-sub {
		font-size: 1.4rem;
		color: #B08A94;
		margin: 0.5rem 0 0;
		font-weight: 300;
	}

	.btn-back {
		position: fixed;
		top: 1.5rem;
		left: 1.5rem;
		z-index: 20;
		background: rgba(10, 5, 6, 0.6);
		backdrop-filter: blur(8px);
		border: 1px solid rgba(155, 27, 48, 0.3);
		color: #B08A94;
		font-size: 1.5rem;
		width: 3rem;
		height: 3rem;
		border-radius: 50%;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s ease;
		font-family: 'Crimson Pro', Georgia, serif;
	}

	.btn-back:hover {
		background: rgba(155, 27, 48, 0.3);
		color: #E8A0B4;
		border-color: rgba(155, 27, 48, 0.5);
	}

	.back-tooltip {
		position: absolute;
		left: 3.5rem;
		top: 50%;
		transform: translateY(-50%);
		background: rgba(10, 5, 6, 0.9);
		backdrop-filter: blur(8px);
		border: 1px solid rgba(155, 27, 48, 0.4);
		color: #E8A0B4;
		font-size: 0.9rem;
		padding: 0.5rem 1rem;
		border-radius: 0.5rem;
		white-space: nowrap;
		opacity: 0;
		pointer-events: none;
		transition: opacity 0.2s ease;
		font-style: italic;
	}

	.btn-back:hover .back-tooltip {
		opacity: 1;
	}

	.auto-scene {
		background: #0A0506;
		cursor: crosshair;
	}

	.auto-canvas {
		position: absolute;
		inset: 0;
	}

	.auto-hud {
		position: fixed;
		bottom: 2rem;
		left: 50%;
		transform: translateX(-50%);
		text-align: center;
		z-index: 10;
		background: rgba(10, 5, 6, 0.7);
		backdrop-filter: blur(12px);
		padding: 1rem 2rem;
		border-radius: 1rem;
		border: 1px solid rgba(155, 27, 48, 0.2);
		animation: hudFadeIn 0.5s ease-out;
	}

	@keyframes hudFadeIn {
		from { opacity: 0; transform: translateX(-50%) scale(0.9); }
		to { opacity: 1; transform: translateX(-50%) scale(1); }
	}

	.auto-hud-title {
		font-family: 'Playfair Display', Georgia, serif;
		font-size: 1.3rem;
		color: #E05A7A;
		font-weight: 700;
		letter-spacing: 0.05em;
	}

	.auto-hud-gen {
		font-size: 0.85rem;
		color: #6A5A5E;
		margin: 0.2rem 0 0.3rem;
		font-variant-numeric: tabular-nums;
	}

	.auto-hud-hint {
		font-size: 0.8rem;
		color: #5A4A4E;
		font-style: italic;
		margin-bottom: 0.6rem;
	}

	.auto-controls {
		display: flex;
		gap: 0.5rem;
		justify-content: center;
	}

	.hud-btn {
		background: rgba(155, 27, 48, 0.25);
		color: #E8A0B4;
		font-size: 0.85rem;
		padding: 0.4rem 1.2rem;
		border: 1px solid rgba(155, 27, 48, 0.3);
		font-family: 'Crimson Pro', Georgia, serif;
		cursor: pointer;
		border-radius: 999px;
		transition: all 0.15s ease;
	}

	.hud-btn:hover {
		background: rgba(155, 27, 48, 0.45);
		color: #FFF5F0;
	}
</style>
