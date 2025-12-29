<script lang="ts">
	import HeadComponent from "$lib/HeadComponent.svelte";
	const GH_BASE_URL = "https://github.com/mistweaverco/juu.nvim/";

	const handleAnchorClick = (evt: Event) => {
		evt.preventDefault();
		const link = evt.currentTarget as HTMLAnchorElement;
		const anchorId = new URL(link.href).hash.replace("#", "");
		const anchor = document.getElementById(anchorId);
		window.scrollTo({
			top: anchor?.offsetTop,
			behavior: "smooth",
		});
	};
	const preventGalleryJump = (evt: Event) => {
		evt.preventDefault();
		const link = evt.currentTarget as HTMLAnchorElement;
		const anchorId = new URL(link.href).hash.replace("#", "");
		if (!anchorId) return;
		// if starts with slide, prevent horizontal jump
		if (anchorId.startsWith("slide")) {
			const currentScroll = window.scrollY;
			const anchor = document.getElementById(anchorId);
			anchor?.scrollIntoView({ behavior: "smooth" });
			window.scrollTo({ top: currentScroll });
		}
	};
	interface Screenshot {
		src: string;
		alt: string;
		title: string;
		text: string;
		ghLink?: {
			slug: string;
			text: string;
		};
	}
	const screenshots: Screenshot[] = [
		{
			src: "/assets/screenshots/notify.png",
			alt: "All default notify types",
			title: "Default types of notify",
			text: "The default notification types (info, debug, warn, error) provided by Juu.nvim with their default styling",
			ghLink: {
				text: "View example code",
				slug: "blob/963854a1c985971dd00c4b3f8b899cd1142e2add/lua/juu/demos/notify/types.lua",
			},
		},
		{
			src: "/assets/screenshots/progress.png",
			alt: "The progress module",
			title: "The progress module",
			text: "Displaying progress for long-running tasks has never been easier with Juu.nvim's progress module",
			ghLink: {
				text: "View example code",
				slug: "blob/963854a1c985971dd00c4b3f8b899cd1142e2add/lua/juu/demos/progress/loading.lua",
			},
		},
	];
</script>

<HeadComponent
	data={{
		title: "Juu.nvim",
		description: "A pretty complete set of Neovim UI components for notification, input and progress.",
	}}
/>

<div id="start" class="hero bg-base-200 min-h-screen">
	<div class="hero-content text-center">
		<div class="max-w-md">
			<img src="/logo.svg" alt="Juu.nvim logo" class="m-5 mx-auto w-64" />
			<h1 class="text-5xl font-bold">Juu.nvim</h1>
			<p class="py-6">A pretty complete set of Neovim UI components for notification, input and progress.</p>
			<a href="#screenshots" on:click={handleAnchorClick}><button class="btn btn-primary">Screenshots</button></a>
		</div>
	</div>
</div>
<div id="screenshots" class="bg-base-200 min-h-screen flex flex-col justify-center">
	<div class="text-center mb-10">
		<h1 class="text-5xl font-bold">Screenshots 📸</h1>
		<p class="pt-6">Some screenshots</p>
	</div>
	<div class="text-center mb-10 w-full max-w-4xl mx-auto carousel carousel-center space-x-4 rounded-box">
		{#each screenshots as image, index (index)}
			<div id={"slide" + (index + 1)} class="carousel-item relative w-full">
				<div class="card bg-base-100 shadow-xl">
					<figure>
						<img src={image.src} alt={image.alt} class="w-full object-contain" />
					</figure>
					<div class="card-body">
						<h2 class="card-title justify-center">{image.title}</h2>
						<p>{image.text}</p>
						{#if image.ghLink}
							<div class="card-actions justify-end mt-4">
								<a href={GH_BASE_URL + image.ghLink.slug} target="_blank" rel="noopener noreferrer">
									<button class="btn btn-block">{image.ghLink.text}</button>
								</a>
							</div>
						{/if}
					</div>
					<div class="absolute left-5 right-5 top-1/2 flex -translate-y-1/2 transform justify-between">
						<a
							on:click={preventGalleryJump}
							href={"#slide" + (index === 0 ? screenshots.length : index)}
							class="btn btn-circle">❮</a
						>
						<a
							on:click={preventGalleryJump}
							href={"#slide" + (index === screenshots.length - 1 ? 1 : index + 2)}
							class="btn btn-circle">❯</a
						>
					</div>
				</div>
			</div>
		{/each}
	</div>
	<div class="text-center">
		<p>
			<a href="#get-involved" on:click={handleAnchorClick}
				><button class="btn btn-secondary mt-5">Get involved</button></a
			>
		</p>
	</div>
</div>
<div id="get-involved" class="hero bg-base-200 min-h-screen">
	<div class="hero-content text-center">
		<div class="max-w-md">
			<h1 class="text-5xl font-bold">Get involved ❤️</h1>
			<p class="py-6">Juu.nvim is open-source and we welcome contributions.</p>
			<p>
				View the <a class="text-secondary" href="https://github.com/mistweaverco/juu.nvim">code.</a>
			</p>
		</div>
	</div>
</div>
