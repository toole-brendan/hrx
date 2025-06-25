import React, { useRef, useEffect } from 'react';
import * as THREE from 'three';
import { SVGLoader } from 'three/examples/jsm/loaders/SVGLoader.js';

const metadata = {
  themes: "transformation, emergence, atomic structure",
  visualization: "Organic branches grow and converge to form a minimalist atomic logo",
  promptSuggestion: "1. Adjust morph timing\n2. Fine-tune orbit scale\n3. Experiment with branch counts\n4. Add particle effects\n5. Create color transitions"
};

const LINGER_START = 0.6;
const LINGER_END = 0.8;
const DELAY_PER_LEVEL = 0.15;
const GROWTH_MULTIPLIER = 3;
const CROSS_BRACE_COUNT = 2;
const WAVE_AMPLITUDE = 0.05;
const MORPH_START = 0.92;

const easeInOut = (t: number): number => {
  return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
};

interface BranchProps {
  start: [number, number, number];
  length: number;
  angle: number;
  depth: number;
  maxDepth: number;
  scale: number;
}

class FractalBranch {
  private lines: THREE.Line[] = [];
  private children: FractalBranch[] = [];
  private group: THREE.Group;
  private disposed: boolean = false;

  constructor(
    private props: BranchProps,
    private parent: THREE.Group,
    private svgPoints: THREE.Vector3[]
  ) {
    this.group = new THREE.Group();
    this.parent.add(this.group);
  }

  update(phase: number): void {
    if (this.disposed) return;

    const { start, length, angle, depth, maxDepth, scale } = this.props;
    const [sx, sy, sz] = start;
    const atMaxDepth = depth === maxDepth;

    // Calculate growth factor
    let growthFactor;
    const morphPhase = (phase - MORPH_START) / (1 - MORPH_START);

    if (phase < MORPH_START) {
      const growthPhase = Math.min(1, Math.max(0, (phase - depth * DELAY_PER_LEVEL) * GROWTH_MULTIPLIER));
      growthFactor = easeInOut(growthPhase);
    } else {
      growthFactor = 1;
    }

    const actualLength = length * growthFactor;
    let ex = sx + Math.cos(angle) * actualLength;
    let ey = sy + Math.sin(angle) * actualLength;
    let ez = sz;

    // Morph branch tips toward logo points
    if (this.svgPoints.length && atMaxDepth && phase >= MORPH_START) {
      const idx = Math.abs(Math.floor(sx * 97 + sy * 31)) % this.svgPoints.length;
      const target = this.svgPoints[idx];
      const t = THREE.MathUtils.smoothstep(phase, MORPH_START, 1.0);
      ex = THREE.MathUtils.lerp(ex, target.x, t);
      ey = THREE.MathUtils.lerp(ey, target.y, t);
      ez = THREE.MathUtils.lerp(ez, target.z, t);
    }

    if (this.lines.length === 0) {
      this.createInitialLines(sx, sy, sz, ex, ey, ez, phase, growthFactor);
    } else {
      this.updateExistingLines(sx, sy, sz, ex, ey, ez, phase, growthFactor);
    }

    // Handle children
    if (depth < maxDepth && phase < MORPH_START && phase >= depth * 0.15) {
      const numBranches = 3 + (depth < 2 ? 1 : 0);

      if (this.children.length === 0) {
        for (let i = 0; i < numBranches; i++) {
          const t = (i + 1) / (numBranches + 1);
          const spread = 0.8 + (depth * 0.1);
          const branchAngle = angle + (t - 0.5) * Math.PI * spread;

          const branchProps: BranchProps = {
            start: [
              sx + (ex - sx) * t,
              sy + (ey - sy) * t,
              sz + (ez - sz) * t
            ],
            length: length * (0.6 - depth * 0.05),
            angle: branchAngle,
            depth: depth + 1,
            maxDepth,
            scale: scale * 0.8
          };

          this.children.push(new FractalBranch(branchProps, this.group, this.svgPoints));
        }
      } else {
        for (let i = 0; i < this.children.length; i++) {
          const t = (i + 1) / (numBranches + 1);
          this.children[i].props.start = [
            sx + (ex - sx) * t,
            sy + (ey - sy) * t,
            sz + (ez - sz) * t
          ];
        }
      }
    }

    this.children.forEach(child => child.update(phase));
  }

  private createInitialLines(sx: number, sy: number, sz: number, ex: number, ey: number, ez: number, phase: number, growthFactor: number): void {
    const mainGeometry = new THREE.BufferGeometry();
    const mainPoints = new Float32Array([sx, sy, sz, ex, ey, ez]);
    mainGeometry.setAttribute('position', new THREE.BufferAttribute(mainPoints, 3));

    const mainMaterial = new THREE.LineBasicMaterial({
      color: 0x333333,
      transparent: true,
      opacity: 0.4,
      linewidth: 0.5
    });

    const mainLine = new THREE.Line(mainGeometry, mainMaterial);
    this.group.add(mainLine);
    this.lines.push(mainLine);

    if (growthFactor > 0.3 && phase < MORPH_START) {
      this.createCrossBraces(sx, sy, sz, ex, ey, ez, phase);
    }
  }

  private createCrossBraces(sx: number, sy: number, sz: number, ex: number, ey: number, ez: number, phase: number): void {
    const { length, angle } = this.props;
    const crossLength = length * (0.2 + Math.sin(phase * Math.PI * 2) * 0.05);
    const crossAngle1 = angle + Math.PI/2;
    const crossAngle2 = angle - Math.PI/2;

    for (let i = 0; i < CROSS_BRACE_COUNT; i++) {
      const t = (i + 1) / 4;
      const px = sx + (ex - sx) * t;
      const py = sy + (ey - sy) * t;
      const pz = sz + (ez - sz) * t;

      const wave = Math.sin(t * Math.PI * 2 + phase * Math.PI * 4) * WAVE_AMPLITUDE;

      const crossGeometry = new THREE.BufferGeometry();
      const crossPoints = new Float32Array([
        px + Math.cos(crossAngle1) * crossLength * (t + wave),
        py + Math.sin(crossAngle1) * crossLength * (t + wave),
        pz,
        px + Math.cos(crossAngle2) * crossLength * (t + wave),
        py + Math.sin(crossAngle2) * crossLength * (t + wave),
        pz
      ]);
      crossGeometry.setAttribute('position', new THREE.BufferAttribute(crossPoints, 3));

      const crossMaterial = new THREE.LineBasicMaterial({
        color: 0x333333,
        transparent: true,
        opacity: 0.4,
        linewidth: 0.5
      });

      const crossLine = new THREE.Line(crossGeometry, crossMaterial);
      this.group.add(crossLine);
      this.lines.push(crossLine);
    }
  }

  private updateExistingLines(sx: number, sy: number, sz: number, ex: number, ey: number, ez: number, phase: number, growthFactor: number): void {
    const mainLine = this.lines[0];
    const positions = mainLine.geometry.attributes.position.array as Float32Array;
    positions[3] = ex;
    positions[4] = ey;
    positions[5] = ez;
    mainLine.geometry.attributes.position.needsUpdate = true;

    // Fade out cross braces during morph
    if (phase >= MORPH_START) {
      const fadeOpacity = 0.4 * (1 - (phase - MORPH_START) / (1 - MORPH_START));
      this.lines.forEach((line, idx) => {
        if (idx > 0) {
          (line.material as THREE.LineBasicMaterial).opacity = fadeOpacity;
        }
      });
    } else if (this.lines.length > 1 && growthFactor > 0.3) {
      const { length, angle } = this.props;
      const crossLength = length * (0.2 + Math.sin(phase * Math.PI * 2) * 0.05);
      
      for (let i = 0; i < CROSS_BRACE_COUNT; i++) {
        const lineIndex = i + 1;
        if (lineIndex < this.lines.length) {
          const crossLine = this.lines[lineIndex];
          const positions = crossLine.geometry.attributes.position.array as Float32Array;
          
          const t = (i + 1) / 4;
          const px = sx + (ex - sx) * t;
          const py = sy + (ey - sy) * t;
          const pz = sz + (ez - sz) * t;

          const wave = Math.sin(t * Math.PI * 2 + phase * Math.PI * 4) * WAVE_AMPLITUDE;
          const crossAngle1 = angle + Math.PI/2;
          const crossAngle2 = angle - Math.PI/2;

          positions[0] = px + Math.cos(crossAngle1) * crossLength * (t + wave);
          positions[1] = py + Math.sin(crossAngle1) * crossLength * (t + wave);
          positions[2] = pz;
          positions[3] = px + Math.cos(crossAngle2) * crossLength * (t + wave);
          positions[4] = py + Math.sin(crossAngle2) * crossLength * (t + wave);
          positions[5] = pz;

          crossLine.geometry.attributes.position.needsUpdate = true;
        }
      }
    }
  }

  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;

    this.children.forEach(child => child.dispose());
    this.children = [];

    this.lines.forEach(line => {
      this.group.remove(line);
      line.geometry.dispose();
      (line.material as THREE.Material).dispose();
    });
    this.lines = [];

    this.parent.remove(this.group);
  }
}

class FractalSystem {
  private branches: FractalBranch[] = [];
  private group: THREE.Group;

  constructor(parentGroup: THREE.Group, private svgPoints: THREE.Vector3[]) {
    this.group = new THREE.Group();
    parentGroup.add(this.group);
    this.initialize();
  }

  private initialize(): void {
    const count = 6;
    const scale = 2;

    for (let i = 0; i < count; i++) {
      const angle = (i / count) * Math.PI * 2;
      const branchProps: BranchProps = {
        start: [
          Math.cos(angle) * scale * 0.2,
          Math.sin(angle) * scale * 0.2,
          0
        ],
        length: scale,
        angle: angle + Math.PI/2,
        depth: 0,
        maxDepth: 7,
        scale: scale
      };

      this.branches.push(new FractalBranch(branchProps, this.group, this.svgPoints));
    }
  }

  update(time: number): void {
    this.branches.forEach(branch => branch.update(time));
  }

  dispose(): void {
    this.branches.forEach(branch => branch.dispose());
    this.branches = [];
    this.group.parent?.remove(this.group);
  }
}

// Embedded SVG data for the atomic logo
const ATOMIC_LOGO_SVG = `<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="100" cy="100" rx="30" ry="80" 
           fill="none" 
           stroke="#000000" 
           stroke-width="3" />
  
  <ellipse cx="100" cy="100" rx="80" ry="30" 
           fill="none" 
           stroke="#000000" 
           stroke-width="3"
           transform="rotate(30 100 100)" />
  
  <ellipse cx="100" cy="100" rx="80" ry="30" 
           fill="none" 
           stroke="#000000" 
           stroke-width="3"
           transform="rotate(-30 100 100)" />
</svg>`;

const FractalLogoReveal: React.FC = () => {
  const containerRef = useRef<HTMLDivElement>(null);
  const cleanupRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    if (!containerRef.current) return;

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(
      75,
      containerRef.current.clientWidth / containerRef.current.clientHeight,
      0.1,
      1000
    );

    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setSize(containerRef.current.clientWidth, containerRef.current.clientHeight);
    renderer.setClearColor(0x000000, 0); // Transparent background
    containerRef.current.appendChild(renderer.domElement);

    camera.position.z = 5;

    const mainGroup = new THREE.Group();
    scene.add(mainGroup);

    const ambientLight = new THREE.AmbientLight(0xffffff, 0.4);
    scene.add(ambientLight);

    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.6);
    directionalLight.position.set(5, 5, 5);
    scene.add(directionalLight);

    const pointLight = new THREE.PointLight(0xffffff, 0.4);
    pointLight.position.set(-5, 3, -5);
    scene.add(pointLight);

    // Load SVG points
    const svgPoints: THREE.Vector3[] = [];
    const loader = new SVGLoader();
    const svgData = loader.parse(ATOMIC_LOGO_SVG);
    
    svgData.paths.forEach((path: any) => {
      const shapes = path.toShapes(true);
      shapes.forEach((shape: any) => {
        const points = shape.getPoints(50);
        points.forEach((point: any) => {
          svgPoints.push(new THREE.Vector3(
            (point.x - 100) / 40,  // Center and scale to fit scene
            -(point.y - 100) / 40, // Flip Y axis
            0
          ));
        });
      });
    });

    const fractalSystem = new FractalSystem(mainGroup, svgPoints);

    // Create logo outline (initially hidden)
    let logoOutline: THREE.Line | null = null;
    const createLogoOutline = () => {
      if (!logoOutline && svgPoints.length > 0) {
        const geometry = new THREE.BufferGeometry().setFromPoints(svgPoints);
        const material = new THREE.LineBasicMaterial({
          color: 0x000000,
          transparent: true,
          opacity: 0,
          linewidth: 2
        });
        logoOutline = new THREE.Line(geometry, material);
        scene.add(logoOutline);
      }
    };

    const clock = new THREE.Clock();
    let animationFrameId: number | null = null;
    let lastFrameTime = 0;

    const CYCLE_LENGTH = 60;
    const GROWTH_PHASE_LENGTH = 30;
    const FRAME_RATE = 20;
    const frameInterval = 1000 / FRAME_RATE;

    const animate = (currentTime: number) => {
      if (!lastFrameTime) {
        lastFrameTime = currentTime;
      }

      const deltaTime = currentTime - lastFrameTime;

      if (deltaTime >= frameInterval) {
        const elapsedTime = clock.getElapsedTime();
        const cycleTime = elapsedTime % CYCLE_LENGTH;
        const isGrowthComplete = cycleTime >= GROWTH_PHASE_LENGTH;
        const time = isGrowthComplete ? 1.0 : (cycleTime / GROWTH_PHASE_LENGTH);

        fractalSystem.update(time);

        // Show logo outline at the end of morph
        if (time >= 0.98) {
          createLogoOutline();
          if (logoOutline) {
            const targetOpacity = 1.0;
            const currentOpacity = (logoOutline.material as THREE.LineBasicMaterial).opacity;
            (logoOutline.material as THREE.LineBasicMaterial).opacity = 
              THREE.MathUtils.lerp(currentOpacity, targetOpacity, 0.1);
          }
        }

        if (isGrowthComplete) {
          const spinStartTime = elapsedTime - GROWTH_PHASE_LENGTH;
          const verySlowRotationSpeed = 0.02;
          mainGroup.rotation.z = spinStartTime * verySlowRotationSpeed;
          mainGroup.rotation.x = 0;
          mainGroup.rotation.y = 0;
        } else {
          mainGroup.rotation.x = 0;
          mainGroup.rotation.y = 0;
          mainGroup.rotation.z = 0;
        }

        renderer.render(scene, camera);

        lastFrameTime = currentTime - (deltaTime % frameInterval);
      }

      animationFrameId = requestAnimationFrame(animate);
    };

    animationFrameId = requestAnimationFrame(animate);

    const handleResize = () => {
      if (!containerRef.current) return;
      camera.aspect = containerRef.current.clientWidth / containerRef.current.clientHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(containerRef.current.clientWidth, containerRef.current.clientHeight);
    };

    window.addEventListener('resize', handleResize);

    cleanupRef.current = () => {
      window.removeEventListener('resize', handleResize);
      if (animationFrameId !== null) {
        cancelAnimationFrame(animationFrameId);
        animationFrameId = null;
      }

      fractalSystem.dispose();

      scene.traverse((object) => {
        if (object instanceof THREE.Mesh) {
          object.geometry.dispose();
          if (Array.isArray(object.material)) {
            object.material.forEach(material => material.dispose());
          } else {
            object.material.dispose();
          }
        } else if (object instanceof THREE.Line) {
          object.geometry.dispose();
          (object.material as THREE.Material).dispose();
        }
      });

      scene.clear();
      ambientLight.dispose();
      directionalLight.dispose();
      pointLight.dispose();
      renderer.dispose();
      renderer.forceContextLoss();

      if (containerRef.current && renderer.domElement.parentNode) {
        containerRef.current.removeChild(renderer.domElement);
      }

      cleanupRef.current = null;
    };

    return () => {
      if (cleanupRef.current) {
        cleanupRef.current();
      }
    };
  }, []);

  return <div ref={containerRef} style={{ width: '100%', height: '100%' }} />;
};

(FractalLogoReveal as any).metadata = metadata;

export default FractalLogoReveal;