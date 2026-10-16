import { Features } from "../components/features";
import { Footer } from "../components/footer";
import { Ethos } from "../components/ethos";
import { Hero } from "../components/hero";
import { Keyboard } from "../components/keyboard";
import { Nav } from "../components/nav";
import { Privacy } from "../components/privacy";
import { Support } from "../components/support";
import { ScrollTop } from "../components/ui/scroll-top";

export default function HomePage() {
  return (
    <>
      <Nav />
      {/* The hero's grid and the logo wall both reach the window edges and set
          their own inner width, so the page width lives on the group below. */}
      <main>
        <Hero />
        <div className="mx-auto max-w-7xl">
          <Features />
          <Privacy />
          <Keyboard />
        </div>
        <Ethos />
        <div className="mx-auto max-w-7xl">
          <Support />
        </div>
      </main>
      <Footer />
      <ScrollTop />
    </>
  );
}
