// Sorry for the very dirty code...  It's just test
import processing.sound.*;
import java.util.Collections;

class Particle
{
  PVector Pos;
  PVector Vel;
  PVector Target;
  float Lerp;
  
  color particleColor;
  color TargetColor;
  float LerpColor;
  
  float Scale;
  float VelS;
  float TargetS;
  float LerpS;
  
  boolean isCycleMode = false;
  boolean isCycleMode_init;
  float TargetR;
  float CurrentR;
  float CurrentTheta;
  float LerpR;
  float RotSp;
  int millis;
  int PreMillis = 0;
  int PreMillis2 = 0;
  int Timer = 0;
  int FrameTimer = 0;
  
  boolean isExplosion = false;
  PVector force;
  float k;
  float m;

  ArrayList<PVector> History = new ArrayList<PVector>();
  static final int MaxIndex = 1;
  static final int FrameSkipFPS = 50;
  
  Particle(PVector Pos, float Scale, float Lerp, float LerpS, float LerpR, 
  float ColorLerp, color particleColor, boolean isCycleMode, int millis)
  {
    this.Pos = Pos.copy();
    this.Target = Pos.copy();
    this.Vel = new PVector(0, 0);
    this.Scale = Scale;
    this.Lerp = Lerp;
    this.particleColor = particleColor;
    this.LerpColor = ColorLerp;
    this.TargetColor = particleColor;
    this.LerpS = LerpS;
    this.LerpR = LerpR;
    this.TargetS = Scale;
    this.isCycleMode_init = isCycleMode;
    this.millis = millis;
  }
  
  void setTarget(PVector Target)
  {
    this.Target = Target.copy();
  }
  
  void setTarget(PVector Target, float TargetR, float RotSp_Rad)
  {
    this.Target = Target.copy();
    this.isCycleMode = this.isCycleMode_init;
    this.Timer = 0;
    this.RotSp = RotSp_Rad;
    this.PreMillis = millis();
    
    this.TargetR = TargetR;
    this.CurrentR = dist(Target.x, Target.y, Pos.x, Pos.y);
    this.CurrentTheta = atan2(Pos.y - Target.y, Pos.x - Target.x);
    this.isExplosion = false;
  }

  void setColorTarget(color newColor)
  {
    this.TargetColor = newColor;
  }
  
  void setScaleTarget(float newScale)
  {
    this.TargetS = newScale;
  }
  
  void setMillis(int newMillis)
  {
    this.millis = newMillis;
  }
  
  void explosion(PVector force, float k, float m)
  {
    this.isExplosion = true;
    this.force = force.copy();
    this.k = k;
    this.m = m;
    this.Vel.add(this.force.copy().div(m));
  }
  
  void update()
  {
    this.FrameTimer += this.PreMillis2 == 0 
      ? 0 : millis() - this.PreMillis2; 
    this.PreMillis2 = millis();
    float FrameSkipMS = 1000 / FrameSkipFPS;
    
    if (this.FrameTimer < FrameSkipMS)
      return;
    if (this.isCycleMode)
      this.Timer = millis() - this.PreMillis;
    
    int SkipLength = floor(this.FrameTimer / FrameSkipMS) + 1;  
    this.FrameTimer = 0;
    
    if (isExplosion)
    {
      PVector newPos = this.Pos.copy()
        .add(this.Vel.copy().mult(FrameSkipMS * 0.01));
      PVector springF = new PVector(
        -this.k * (newPos.x - this.Target.x),
        -this.k * (newPos.y - this.Target.y)
      );
      this.Vel.add(springF.div(this.m));
      this.Pos.add(this.Vel.copy().mult(FrameSkipMS * 0.01));
    }
    else if (isCycleMode)
    {
      this.CurrentTheta += this.RotSp;
      this.CurrentR += (this.TargetR - this.CurrentR) 
        * (1 - pow(this.LerpR - 1, SkipLength - 1) * pow(this.LerpR, 1 - SkipLength));
      this.Pos.set(
        this.Target.x + this.CurrentR * cos(this.CurrentTheta),
        this.Target.y + this.CurrentR * sin(this.CurrentTheta)
      );
      
      if (this.Timer >= this.millis)
        this.isCycleMode = false;
    }
    else
    {
      this.Vel = new PVector(
        (this.Target.x - this.Pos.x) 
        * (1 - pow(this.Lerp - 1, SkipLength - 1) * pow(this.Lerp, 1 - SkipLength)),
        (this.Target.y - this.Pos.y) 
        * (1 - pow(this.Lerp - 1, SkipLength - 1) * pow(this.Lerp, 1 - SkipLength))
      );
      this.Pos.add(this.Vel);
    }
    
    this.VelS = (this.TargetS - this.Scale) 
      * (1 - pow(this.LerpS - 1, SkipLength - 1) * pow(this.LerpS, 1 - SkipLength));
    this.Scale += this.VelS;
        
    this.particleColor = lerpColor(
      this.particleColor,
      this.TargetColor,
      this.LerpColor
    );
    
    this.History.add(this.Pos.copy());
      if (this.History.size() > MaxIndex)
        this.History.remove(0);
  }
  
  void render()
  {
    noStroke();
    fill(this.particleColor);
    ellipse(
      this.Pos.x, this.Pos.y, 
      this.Scale, this.Scale
    );
    /*for (int i=0; i < this.History.size(); i++)
    {
      PVector Vec = this.History.get(i);
      fill(this.particleColor, map(i, 0, this.History.size(), 255, 0));
      ellipse(
        Vec.x, Vec.y, 
        this.Scale, this.Scale
      );
    }*/
  }
}

class ParticleSystem
{
  PImage CurrentImage;
  ArrayList<Particle> ParticleList = new ArrayList<Particle>();
  ArrayList<Particle> Remain = new ArrayList<Particle>();
  int Interval;
  float Scale;
  float Lerp;
  
  FFT fft;
  AudioIn in;
  
  static final float k = 2;
  static final float m = 1;
  static final float explosion = 500;
  static final float limit = 0.1;
  static final int range = 5;
  static final int bands = 512;
  static final int spectrumCatch = 1;
  static final int explosionDelay = 500;
  int explosionTimer = 0;
  int preTime = 0;
  
  float[] spectrum = new float[bands];
  
  ParticleSystem(PImage Image, int Interval, float Lerp, int width, int height,
    FFT fft, AudioIn in)
  {
    this.fft = fft;
    this.in = in;
    in.start();
    fft.input(in);
    
    this.CurrentImage = Image.copy();
    this.Interval = Interval;
    this.Scale = Interval;
    this.Lerp = Lerp;
    
    this.CurrentImage.loadPixels();

    for (int i=0; i < this.CurrentImage.height; i += Interval)
    {
      for (int j=0; j < this.CurrentImage.width; j += Interval)
      {
        int index = ((i - 1) 
          - (i - 1) % Interval) / Interval 
          + ((j - 1) 
          - (j - 1) % Interval) / Interval;
        color c = this.CurrentImage.get(j, i);
        Particle newParticle = new Particle(
          getSideVec(),
          //map(saturation(c), 0, 255, this.Scale * 0.45, this.Scale),
          this.Scale,
          Lerp, Lerp, 10, 0.15,
          color(255), true, index * 20 + 500
        );
        newParticle.setColorTarget(c);
        newParticle.setTarget(new PVector(
          j + width * 0.5 - this.CurrentImage.width * 0.5, 
          i + height * 0.5 - this.CurrentImage.height * 0.5
        ), 30, ((new float[] { -.15, .15 })[int(random(2))]));
        this.ParticleList.add(newParticle);
      }
    }
  }
  
  PVector getSideVec()
  {
    int[][] side = {
      { width + 100, height + 100 },
      { -100, -100 }
    };
    int randomize1 = int(random(2));
    int randomize2 = int(random(2));
    
    PVector newPos = randomize1 == 0 
      ? new PVector(
        random(width),
        side[randomize2][1 - randomize1]
      )
      : new PVector(
        side[randomize2][1 - randomize1],
        random(height)
      );
      
    return newPos;
  }
  
  void changeImage(PImage newImage)
  {
    this.CurrentImage = newImage.copy();
    this.CurrentImage.loadPixels();
    
    int w = ((this.CurrentImage.width - 1) 
      - (this.CurrentImage.width - 1) % Interval) / Interval;
    int h = ((this.CurrentImage.height - 1) 
      - (this.CurrentImage.height - 1) % Interval) / Interval;
    int Length = (w + 1) * (h + 1);  
    int diff = Length - this.ParticleList.size();
    int Remain = this.Remain.size();

    for (int i=0; i < abs(diff); i++)
    {
      if (diff > 0)
      {
        if (Remain > i)
        {
          this.ParticleList.add(this.Remain.get(0));
          this.Remain.remove(0);
        }
        else
        {
          Particle newParticle = new Particle(
            getSideVec().copy(),
            this.Scale,
            this.Lerp, this.Lerp, 10, 0.15,
            color(255), true, 0
          );
          this.ParticleList.add(newParticle);
        }
      }
      else
      {
        this.ParticleList.get(0).setColorTarget(color(255));
        this.ParticleList.get(0).setTarget(getSideVec());
        this.Remain.add(this.ParticleList.get(0));
        this.ParticleList.remove(0);
      }
    }

    Collections.shuffle(this.ParticleList);
    
    int k = 0;
    for (int i=0; i < this.CurrentImage.height; i += Interval)
    {
      for (int j=0; j < this.CurrentImage.width; j += Interval)
      {
        int index = ((i - 1) 
          - (i - 1) % Interval) / Interval 
          + ((j - 1) 
          - (j - 1) % Interval) / Interval;
        color c = this.CurrentImage.get(j, i);
        this.ParticleList.get(k).setMillis(index * 20 + 500);
        this.ParticleList.get(k).setColorTarget(c);
        this.ParticleList.get(k).setTarget(new PVector(
          j + width * 0.5 - this.CurrentImage.width * 0.5, 
          i + height * 0.5 - this.CurrentImage.height * 0.5
        ), 30, (new float[] { -.15, .15 })[int(random(2))]);
        this.ParticleList.get(k).setScaleTarget(/*map(
          saturation(c), 0, 255, 
          this.Scale * 0.45, */this.Scale
        //));
        );
        k++;
      }
    }
  }
  
  void explosion()
  {
    //println("explosion");
    int newRange = int(random(1, range + 1));
    int currentX = int(random(
      newRange, 
      round(this.CurrentImage.width / this.Interval) - newRange + 1
    ));
    int currentY = int(random(
      newRange, 
      round(this.CurrentImage.height  / this.Interval) - newRange + 1
    ));
    
    for (float i=-90; i < 180; i += 10)
    {
      float rad = radians(i);
      
      int right_x = round(currentX + newRange * cos(rad));
      int left_x = round(currentX + newRange * -cos(rad));
      int y = round(currentY + newRange * sin(rad));

      for (int j=0; j < abs(right_x - left_x); j++)
      {
        float a = 2 * rad * (j / abs(right_x - left_x));
        PVector force = new PVector(
          random(explosion) * cos(abs(a - rad)) 
            * (a - rad == 0 ? 1 : (a - rad) / abs(a - rad)),
          random(explosion) * sin(abs(a - rad)) 
              * (a - rad == 0 ? 1 : (a - rad) / abs(a - rad))
        );

        ParticleList.get(
          round(y * floor(this.CurrentImage.width / this.Interval) 
           + currentX + j - abs(right_x - left_x) / 2)
        ).explosion(force, k, m);
      }
    }
  }
  
  void update()
  {
    for (Particle p : ParticleList)
      p.update();
      
    for (Particle p : Remain)
      p.update();
      
    fft.analyze(spectrum);
    if (this.explosionTimer < explosionDelay)
      this.explosionTimer += this.preTime == 0 
        ? 0: millis() - this.preTime;
    this.preTime = millis();

    /*if (spectrum[spectrumCatch] * 1000 > limit 
      && this.explosionTimer >= explosionDelay)
    {
      this.explosionTimer = 0;
      explosion();
    }*/
  }
  
  void render()
  {
    for (Particle p : ParticleList)
      p.render();
      
    for (Particle p : Remain)
      p.render();
  }
}

ParticleSystem p;
String[] Photos = {
  "1.jpg",
  "2.jpg",
  "3.jpg",
  "4.jpg",
  "5.jpg",
  "6.jpg",
  "7.jpg"
};
int index = 0;
int MaxFrame = 50;
int Frame = MaxFrame;
  
void setup()
{
  size(1000, 1000);
  p = new ParticleSystem(
    loadImage(Photos[0]),
    8, 3,
    width, height,
    new FFT(this, 512), new AudioIn(this, 0)
  );
}

void draw()
{
  clear();
  background(255);
  
  if (MaxFrame > Frame)
    Frame++;
  
  p.update();
  p.render();
}

void keyPressed()
{
  if (keyCode != ENTER)
    return;
  
  if (MaxFrame <= Frame)
    Frame = 0;
  else 
    return;
    
  index = index == Photos.length - 1 ? 0 : index + 1;
  p.changeImage(loadImage(Photos[index]));
}
