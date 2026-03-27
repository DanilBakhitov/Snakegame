program SnakeGame;

uses
  Graph, Crt, Dos, SysUtils, Windows;

{ ========================= Константы ========================= }

const
  Width = 800;
  Height = 600;
  CellSize = 20;
  MaxTopScores = 5;
  BonusDuration = 7000;
  TargetScore = 1000;
  ScoreFile = 'highscores.txt';

{ ======================== Типы данных ======================== }

type
  PNode = ^TNode;
  TNode = record
    x, y: Integer;
    next: PNode;
  end;

  TFood = record
    x, y: Integer;
    isBonus: Boolean;
    createdAt: LongInt;
  end;

  TScore = record
    Points: Integer;
  end;

  TSnake = record
    Head, Tail: PNode;
    dx, dy: Integer;
    NextDx, NextDy: Integer;
    Score: Integer;
    Alive: Boolean;
    Color: Word;
  end;

{ ======================== Глобальные переменные ======================== }

var
  gd, gm: SmallInt;
  PlayerSnake, RivalSnake: TSnake;
  Food: TFood;
  Level, DelayTime: Integer;
  GameOver: Boolean;
  EndTitle, EndDetails: String;
  HighScores: array[1..MaxTopScores] of TScore;

{ ======================== Системные процедуры ======================== }

procedure HideConsole;
begin
  ShowWindow(GetConsoleWindow, SW_HIDE);
end;

procedure InitGraphics;
begin
  gd := Detect;
  InitGraph(gd, gm, '');
  if GraphResult <> grOk
  then
    begin
      Writeln('Ошибка графики: ', GraphErrorMsg(GraphResult));
      Halt(1);
    end;
end;

{ ======================== Работа со змейками ======================== }

procedure AddSegment(var Snake: TSnake; x, y: Integer);
var
  NewNode: PNode;
begin
  New(NewNode);
  NewNode^.x := x;
  NewNode^.y := y;
  NewNode^.next := Snake.Head;
  Snake.Head := NewNode;

  if Snake.Tail = nil
  then
    Snake.Tail := NewNode;
end;

procedure RemoveTail(var Snake: TSnake);
var
  temp, prev: PNode;
begin
  if Snake.Head = nil
  then
    Exit;

  temp := Snake.Head;
  prev := nil;
  while temp^.next <> nil
  do
    begin
      prev := temp;
      temp := temp^.next;
    end;

  if prev <> nil
  then
    begin
      Dispose(temp);
      prev^.next := nil;
      Snake.Tail := prev;
    end
  else
    begin
      Dispose(Snake.Head);
      Snake.Head := nil;
      Snake.Tail := nil;
    end;
end;

procedure ClearSnake(var Snake: TSnake);
begin
  while Snake.Head <> nil
  do
    RemoveTail(Snake);

  Snake.dx := 0;
  Snake.dy := 0;
  Snake.NextDx := 0;
  Snake.NextDy := 0;
  Snake.Alive := False;
end;

procedure InitSnake(var Snake: TSnake; StartX, StartY, StartDx, StartDy: Integer; SnakeColor: Word);
begin
  ClearSnake(Snake);
  Snake.dx := StartDx;
  Snake.dy := StartDy;
  Snake.NextDx := 0;
  Snake.NextDy := 0;
  Snake.Score := 0;
  Snake.Alive := True;
  Snake.Color := SnakeColor;
  AddSegment(Snake, StartX, StartY);
end;

function SnakeCollides(const Snake: TSnake; x, y: Integer; IgnoreTail: Boolean): Boolean;
var
  temp: PNode;
begin
  temp := Snake.Head;
  while temp <> nil
  do
    begin
      if IgnoreTail and (temp^.next = nil)
      then
        begin
          temp := temp^.next;
          continue;
        end;

      if (temp^.x = x) and (temp^.y = y)
      then
        begin
          SnakeCollides := True;
          Exit;
        end;

      temp := temp^.next;
    end;

  SnakeCollides := False;
end;

function IsOutOfBounds(x, y: Integer): Boolean;
begin
  IsOutOfBounds :=
    (x < 0) or (y < 0) or
    (x >= Width div CellSize) or (y >= Height div CellSize);
end;

function OccupiedByAnySnake(x, y: Integer): Boolean;
begin
  OccupiedByAnySnake :=
    SnakeCollides(PlayerSnake, x, y, False) or
    (RivalSnake.Alive and SnakeCollides(RivalSnake, x, y, False));
end;

function FoodPoints: Integer;
begin
  if Food.isBonus
  then
    FoodPoints := 30
  else
    FoodPoints := 10;
end;

procedure DrawSnake(const Snake: TSnake);
var
  temp: PNode;
begin
  if not Snake.Alive
  then
    Exit;

  SetColor(Snake.Color);
  SetFillStyle(SolidFill, Snake.Color);
  temp := Snake.Head;
  while temp <> nil
  do
    begin
      Bar(temp^.x * CellSize,
          temp^.y * CellSize,
          (temp^.x + 1) * CellSize,
          (temp^.y + 1) * CellSize);
      temp := temp^.next;
    end;
end;

{ ======================== Работа с едой ======================== }

procedure GenerateFood;
begin
  repeat
    Food.x := Random(Width div CellSize - 2) + 1;
    Food.y := Random(Height div CellSize - 2) + 1;
  until not OccupiedByAnySnake(Food.x, Food.y);

  Food.isBonus := Random(5) = 0;
  if Food.isBonus
  then
    Food.createdAt := GetTickCount;
end;

procedure DrawFood;
begin
  if Food.isBonus
  then
    begin
      SetColor(Magenta);
      SetFillStyle(SolidFill, Magenta);
      FillEllipse(Food.x * CellSize + CellSize div 2,
                  Food.y * CellSize + CellSize div 2,
                  CellSize div 2, CellSize div 2);
    end
  else
    begin
      SetColor(Red);
      SetFillStyle(SolidFill, Red);
      Bar(Food.x * CellSize,
          Food.y * CellSize,
          (Food.x + 1) * CellSize,
          (Food.y + 1) * CellSize);
    end;
end;

{ ======================== Уровни и скорость ======================== }

procedure UpdateLevel;
begin
  Level := PlayerSnake.Score div 50 + 1;
  DelayTime := 150 - Level * 10;
  if DelayTime < 40
  then
    DelayTime := 40;
end;

{ ======================== Границы и информация ======================== }

procedure DrawBorder;
begin
  SetColor(White);
  SetLineStyle(SolidLn, 0, NormWidth);
  Graph.Rectangle(0, 0, Width - 1, Height - 1);
end;

procedure DrawInfo;
begin
  SetColor(White);
  OutTextXY(10, 10, 'Player: ' + IntToStr(PlayerSnake.Score));
  OutTextXY(10, 25, 'Rival: ' + IntToStr(RivalSnake.Score));
  OutTextXY(10, 40, 'Level: ' + IntToStr(Level));
  if RivalSnake.Alive
  then
    OutTextXY(10, 55, 'Rival status: hunting')
  else
    OutTextXY(10, 55, 'Rival status: defeated');
end;

procedure DrawScene;
begin
  ClearDevice;
  DrawBorder;
  DrawSnake(PlayerSnake);
  DrawSnake(RivalSnake);
  DrawFood;
  DrawInfo;
end;

procedure FinishRound(const TitleText, DetailText: String);
begin
  GameOver := True;
  EndTitle := TitleText;
  EndDetails := DetailText;
end;

function WaitForRestartChoice: Boolean;
begin
  repeat
    Delay(20);

    if (GetAsyncKeyState(VK_R) and $8000) <> 0
    then
      begin
        WaitForRestartChoice := True;
        Exit;
      end;

    if (GetAsyncKeyState(VK_ESCAPE) and $8000) <> 0
    then
      begin
        WaitForRestartChoice := False;
        Exit;
      end;
  until False;
end;

function ShowEndScreen: Boolean;
begin
  SetColor(White);
  OutTextXY(280, 200, EndTitle);
  OutTextXY(220, 225, EndDetails);
  OutTextXY(250, 255, 'Player score: ' + IntToStr(PlayerSnake.Score));
  OutTextXY(250, 275, 'Rival score: ' + IntToStr(RivalSnake.Score));
  OutTextXY(200, 320, 'Press R to restart or Esc to exit');
  ShowEndScreen := WaitForRestartChoice;
end;

{ ======================== Управление ======================== }

function IsOppositeDirection(CurrentDx, CurrentDy, RequestedDx, RequestedDy: Integer): Boolean;
begin
  IsOppositeDirection :=
    (CurrentDx + RequestedDx = 0) and
    (CurrentDy + RequestedDy = 0);
end;

procedure QueueDirection(var Snake: TSnake; RequestDx, RequestDy: Integer);
begin
  if not IsOppositeDirection(Snake.dx, Snake.dy, RequestDx, RequestDy)
  then
    begin
      Snake.NextDx := RequestDx;
      Snake.NextDy := RequestDy;
    end;
end;

procedure ApplyQueuedDirection(var Snake: TSnake);
begin
  if ((Snake.NextDx <> 0) or (Snake.NextDy <> 0)) and
     not IsOppositeDirection(Snake.dx, Snake.dy, Snake.NextDx, Snake.NextDy)
  then
    begin
      Snake.dx := Snake.NextDx;
      Snake.dy := Snake.NextDy;
    end;

  Snake.NextDx := 0;
  Snake.NextDy := 0;
end;

procedure HandleInput;
begin
  if (GetAsyncKeyState(VK_UP) and $8000) <> 0
  then
    QueueDirection(PlayerSnake, 0, -1);

  if (GetAsyncKeyState(VK_DOWN) and $8000) <> 0
  then
    QueueDirection(PlayerSnake, 0, 1);

  if (GetAsyncKeyState(VK_LEFT) and $8000) <> 0
  then
    QueueDirection(PlayerSnake, -1, 0);

  if (GetAsyncKeyState(VK_RIGHT) and $8000) <> 0
  then
    QueueDirection(PlayerSnake, 1, 0);
end;

function IsSafeMove(const Snake, OtherSnake: TSnake; RequestDx, RequestDy: Integer): Boolean;
var
  nextX, nextY: Integer;
  IgnoreOwnTail: Boolean;
begin
  if (RequestDx = 0) and (RequestDy = 0)
  then
    begin
      IsSafeMove := False;
      Exit;
    end;

  if IsOppositeDirection(Snake.dx, Snake.dy, RequestDx, RequestDy)
  then
    begin
      IsSafeMove := False;
      Exit;
    end;

  nextX := Snake.Head^.x + RequestDx;
  nextY := Snake.Head^.y + RequestDy;

  if IsOutOfBounds(nextX, nextY)
  then
    begin
      IsSafeMove := False;
      Exit;
    end;

  IgnoreOwnTail := not ((nextX = Food.x) and (nextY = Food.y));
  if SnakeCollides(Snake, nextX, nextY, IgnoreOwnTail)
  then
    begin
      IsSafeMove := False;
      Exit;
    end;

  if OtherSnake.Alive and SnakeCollides(OtherSnake, nextX, nextY, False)
  then
    begin
      IsSafeMove := False;
      Exit;
    end;

  IsSafeMove := True;
end;

procedure UpdateRivalDirection;
var
  deltaX, deltaY: Integer;
  Chosen: Boolean;

  procedure TryDirection(RequestDx, RequestDy: Integer);
  begin
    if Chosen
    then
      Exit;

    if IsSafeMove(RivalSnake, PlayerSnake, RequestDx, RequestDy)
    then
      begin
        QueueDirection(RivalSnake, RequestDx, RequestDy);
        Chosen := True;
      end;
  end;

begin
  if not RivalSnake.Alive
  then
    Exit;

  deltaX := Food.x - RivalSnake.Head^.x;
  deltaY := Food.y - RivalSnake.Head^.y;
  Chosen := False;

  if Abs(deltaX) >= Abs(deltaY)
  then
    begin
      if deltaX > 0 then TryDirection(1, 0);
      if deltaX < 0 then TryDirection(-1, 0);
      if deltaY > 0 then TryDirection(0, 1);
      if deltaY < 0 then TryDirection(0, -1);
    end
  else
    begin
      if deltaY > 0 then TryDirection(0, 1);
      if deltaY < 0 then TryDirection(0, -1);
      if deltaX > 0 then TryDirection(1, 0);
      if deltaX < 0 then TryDirection(-1, 0);
    end;

  TryDirection(RivalSnake.dx, RivalSnake.dy);
  TryDirection(1, 0);
  TryDirection(-1, 0);
  TryDirection(0, 1);
  TryDirection(0, -1);
end;

{ ======================== Таблица рекордов ======================== }

procedure LoadScores;
var
  f: TextFile;
  i: Integer;
begin
  AssignFile(f, ScoreFile);
  if not FileExists(ScoreFile)
  then
    Exit;

  Reset(f);
  for i := 1 to MaxTopScores
  do
    begin
      if EOF(f)
      then
        Break;
      ReadLn(f, HighScores[i].Points);
    end;
  CloseFile(f);
end;

procedure SaveScore(newScore: Integer);
var
  i, j: Integer;
  f: TextFile;
begin
  for i := 1 to MaxTopScores
  do
    if newScore > HighScores[i].Points
    then
      begin
        for j := MaxTopScores downto i + 1
        do
          HighScores[j] := HighScores[j - 1];
        HighScores[i].Points := newScore;
        Break;
      end;

  AssignFile(f, ScoreFile);
  Rewrite(f);
  for i := 1 to MaxTopScores
  do
    WriteLn(f, HighScores[i].Points);
  CloseFile(f);
end;

{ ======================== Главный игровой цикл ======================== }

function GameLoop: Boolean;
var
  PlayerNextX, PlayerNextY: Integer;
  RivalNextX, RivalNextY: Integer;
  currentTime, lastMoveTime: DWORD;
  PlayerWillEat, RivalWillEat: Boolean;
  PlayerDead, RivalDead: Boolean;
  AteFood: Boolean;
  PointsAwarded: Integer;
begin
  Randomize;
  InitSnake(PlayerSnake, 10, 10, 1, 0, Green);
  InitSnake(RivalSnake, (Width div CellSize) - 11, (Height div CellSize) - 11, -1, 0, Yellow);
  Level := 1;
  DelayTime := 150;
  GameOver := False;
  EndTitle := '';
  EndDetails := '';
  LoadScores;
  GenerateFood;
  DrawScene;
  lastMoveTime := GetTickCount;

  repeat
    HandleInput;
    currentTime := GetTickCount;

    if Food.isBonus and (currentTime - Food.createdAt > BonusDuration)
    then
      begin
        GenerateFood;
        DrawScene;
      end;

    if (currentTime - lastMoveTime) >= DelayTime
    then
      begin
        ApplyQueuedDirection(PlayerSnake);
        UpdateRivalDirection;
        ApplyQueuedDirection(RivalSnake);

        PlayerNextX := PlayerSnake.Head^.x + PlayerSnake.dx;
        PlayerNextY := PlayerSnake.Head^.y + PlayerSnake.dy;
        PlayerWillEat := (PlayerNextX = Food.x) and (PlayerNextY = Food.y);

        RivalDead := not RivalSnake.Alive;
        RivalWillEat := False;
        if RivalSnake.Alive
        then
          begin
            RivalNextX := RivalSnake.Head^.x + RivalSnake.dx;
            RivalNextY := RivalSnake.Head^.y + RivalSnake.dy;
            RivalWillEat := (RivalNextX = Food.x) and (RivalNextY = Food.y);
          end
        else
          begin
            RivalNextX := -1;
            RivalNextY := -1;
          end;

        PlayerDead :=
          IsOutOfBounds(PlayerNextX, PlayerNextY) or
          SnakeCollides(PlayerSnake, PlayerNextX, PlayerNextY, not PlayerWillEat);

        if RivalSnake.Alive
        then
          begin
            RivalDead :=
              IsOutOfBounds(RivalNextX, RivalNextY) or
              SnakeCollides(RivalSnake, RivalNextX, RivalNextY, not RivalWillEat);

            if not PlayerDead and
               SnakeCollides(RivalSnake, PlayerNextX, PlayerNextY, not RivalWillEat)
            then
              PlayerDead := True;

            if not RivalDead and
               SnakeCollides(PlayerSnake, RivalNextX, RivalNextY, not PlayerWillEat)
            then
              RivalDead := True;

            if (PlayerNextX = RivalNextX) and (PlayerNextY = RivalNextY)
            then
              begin
                PlayerDead := True;
                RivalDead := True;
              end;
          end;

        if PlayerDead
        then
          begin
            if RivalDead
            then
              FinishRound('Both snakes lost', 'Player and rival collided on the same move.')
            else
              FinishRound('Player lost', 'The player snake crashed or touched the rival.');
            Break;
          end;

        if RivalDead and RivalSnake.Alive
        then
          begin
            FinishRound('Rival lost', 'The rival snake crashed before reaching the target score.');
            Break;
          end;

        AddSegment(PlayerSnake, PlayerNextX, PlayerNextY);
        AteFood := False;

        if PlayerWillEat
        then
          begin
            PointsAwarded := FoodPoints;
            Inc(PlayerSnake.Score, PointsAwarded);
            UpdateLevel;
            AteFood := True;
          end
        else
          RemoveTail(PlayerSnake);

        if RivalSnake.Alive
        then
          begin
            if RivalDead
            then
              ClearSnake(RivalSnake)
            else
              begin
                AddSegment(RivalSnake, RivalNextX, RivalNextY);
                if RivalWillEat and not PlayerWillEat
                then
                  begin
                    PointsAwarded := FoodPoints;
                    Inc(RivalSnake.Score, PointsAwarded);
                    AteFood := True;
                  end
                else
                  RemoveTail(RivalSnake);
              end;
          end;

        if PlayerSnake.Score >= TargetScore
        then
          begin
            FinishRound('Player won', 'The player snake reached ' + IntToStr(TargetScore) + ' points.');
            DrawScene;
            Break;
          end;

        if RivalSnake.Score >= TargetScore
        then
          begin
            FinishRound('Rival won', 'The rival snake reached ' + IntToStr(TargetScore) + ' points.');
            DrawScene;
            Break;
          end;

        if AteFood or (RivalWillEat and not PlayerWillEat)
        then
          GenerateFood;

        DrawScene;
        lastMoveTime := currentTime;
      end
    else
      Delay(10);
  until GameOver;

  SaveScore(PlayerSnake.Score);
  GameLoop := ShowEndScreen;

  ClearSnake(PlayerSnake);
  ClearSnake(RivalSnake);
end;

{ ======================== Запуск программы ======================== }

begin
  HideConsole;
  InitGraphics;

  repeat
  until not GameLoop;

  CloseGraph;
end.

