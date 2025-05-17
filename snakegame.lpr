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

{ ======================== Глобальные переменные ======================== }

var
  gd, gm: SmallInt;
  SnakeHead, SnakeTail: PNode;
  dx, dy: Integer;
  Food: TFood;
  Score, Level, DelayTime: Integer;
  GameOver: Boolean;
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

{ ======================== Работа со змейкой ======================== }

procedure AddSegment(x, y: Integer);
var
  NewNode: PNode;
begin
  New(NewNode);
  NewNode^.x := x;
  NewNode^.y := y;
  NewNode^.next := SnakeHead;
  SnakeHead := NewNode;

  if SnakeTail = nil
  then
    SnakeTail := NewNode;
end;

procedure RemoveTail;
var
  temp, prev: PNode;
begin
   temp := SnakeHead;
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
     SnakeTail := prev;
    end
  else
    begin
     Dispose(SnakeHead);
     SnakeHead := nil;
     SnakeTail := nil;
     end;
end;

procedure DrawSnake;
var
  temp: PNode;
begin
  SetColor(Green);
  SetFillStyle(SolidFill, Green);
  temp := SnakeHead;
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

function Collides(x, y: Integer): Boolean;
var
  temp: PNode;
begin
  temp := SnakeHead;
  while temp <> nil
        do
        begin
         if (temp^.x = x) and (temp^.y = y)
           then
               begin
               Collides := True;
               Exit;
               end;
               temp := temp^.next;
        end;
  Collides := False;
end;

{ ======================== Работа с едой ======================== }

procedure GenerateFood;
begin
  Randomize;

  repeat
    Food.x := Random(Width div CellSize - 2) + 1;
    Food.y := Random(Height div CellSize - 2) + 1;
  until not Collides(Food.x, Food.y);

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
  Level := Score div 50 + 1;
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
  OutTextXY(10, 10, 'Score: ' + IntToStr(Score));
  OutTextXY(10, 25, 'Level: ' + IntToStr(Level));
end;

{ ======================== Управление ======================== }

procedure HandleInput;
begin
  if (GetAsyncKeyState(VK_UP) and $8000) <> 0
    then
      if dy = 0
      then
          begin
            dx := 0; dy := -1;
          end;

  if (GetAsyncKeyState(VK_DOWN) and $8000) <> 0
    then
        if dy = 0
        then
            begin
              dx := 0; dy := 1;
            end;

  if (GetAsyncKeyState(VK_LEFT) and $8000) <> 0
    then
        if dx = 0
          then
              begin
                dx := -1; dy := 0;
              end;

  if (GetAsyncKeyState(VK_RIGHT) and $8000) <> 0
    then
    if dx = 0
      then
          begin
            dx := 1; dy := 0;
          end;
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
         break;
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
        for j := MaxTopScores downto i + 1 do
          HighScores[j] := HighScores[j - 1];
        HighScores[i].Points := newScore;
        break;
      end;

  AssignFile(f, ScoreFile);
  Rewrite(f);
  for i := 1 to MaxTopScores
  do
    WriteLn(f, HighScores[i].Points);
    CloseFile(f);
end;

{ ======================== Главный игровой цикл ======================== }

procedure GameLoop;
var
  headX, headY: Integer;
begin
  dx := 1; dy := 0;
  Score := 0;
  Level := 1;
  DelayTime := 150;
  GameOver := False;

  AddSegment(10, 10);
  GenerateFood;
  LoadScores;

  repeat
    ClearDevice;
    HandleInput;

    headX := SnakeHead^.x + dx;
    headY := SnakeHead^.y + dy;

    if (headX < 0) or (headY < 0) or
       (headX >= Width div CellSize) or (headY >= Height div CellSize) or
       Collides(headX, headY)
    then
      begin
        GameOver := True;
        Break;
      end;

      AddSegment(headX, headY);

      if (headX = Food.x) and (headY = Food.y)
      then
        begin
          if Food.isBonus
          then
            Inc(Score, 30)
          else
            Inc(Score, 10);

          GenerateFood;
          UpdateLevel;
        end
      else
      RemoveTail;

      if Food.isBonus and (GetTickCount - Food.createdAt > BonusDuration)
         then
           GenerateFood;

      DrawBorder;
      DrawSnake;
      DrawFood;
      DrawInfo;
      Delay(DelayTime);
  until GameOver;

      SetColor(White);
      OutTextXY(300, 200, 'GAME OVER!');
      OutTextXY(300, 220, 'Score: ' + IntToStr(Score));
      SaveScore(Score);
      ReadLn;
end;

{ ======================== Запуск программы ======================== }

begin
  HideConsole;
  InitGraphics;
  GameLoop;
  CloseGraph;
end.
