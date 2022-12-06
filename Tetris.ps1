using Namespace System.Drawing
using Namespace System.Windows.Forms

enum ShapeTypes {
    Unspecified = 0        
    Line = 1    
    T = 2    
    Square = 3    
    L = 4   
    LMirrored = 5 
    S = 6   
    SMirrored = 7 
}

class TetrisShape {
    [System.Drawing.Point] $Position
    [System.Drawing.Color] $Color
    [ShapeTypes] $Type = 0
    [int[, ]] $Body
    
    [PSCustomObject] $Moveset = [PSCustomObject] @{
        Left  = $false
        Right = $false
        Up    = $false
        Down  = $false
    }

    [int[, ]] SetShape([ShapeTypes] $Type) {
        $Coordinates = [int[, ]]::new(5, 5)
        Switch ([int]$Type) {
            Default {
                $Coordinates[2, 0] = 1
                $Coordinates[2, 1] = 1
                $Coordinates[2, 2] = 1
                $Coordinates[2, 3] = 1
            }
            2 {
                $Coordinates[2, 1] = 1
                $Coordinates[2, 2] = 1
                $Coordinates[2, 3] = 1
                $Coordinates[1, 2] = 1
            }
            3 {
                $Coordinates[2, 2] = 1
                $Coordinates[2, 3] = 1
                $Coordinates[3, 2] = 1
                $Coordinates[3, 3] = 1
            }
            4 {
                $Coordinates[1, 2] = 1
                $Coordinates[1, 3] = 1
                $Coordinates[2, 2] = 1
                $Coordinates[3, 2] = 1
            }
            5 {
                $Coordinates[1, 1] = 1
                $Coordinates[1, 2] = 1
                $Coordinates[2, 2] = 1
                $Coordinates[3, 2] = 1
            }
            6 {
                $Coordinates[1, 2] = 1
                $Coordinates[2, 1] = 1
                $Coordinates[2, 2] = 1
                $Coordinates[3, 1] = 1
            }
            7 {
                $Coordinates[1, 2] = 1
                $Coordinates[2, 2] = 1
                $Coordinates[2, 3] = 1
                $Coordinates[3, 3] = 1
            }
        }
        Return $Coordinates
    }

    [bool] IsColliding([int[, ]] $Body, [int[, ]] $Table, [System.Drawing.Point] $Position) {
        For ($Y = 0; $Y -le $Body.GetUpperBound(1); $Y++) {
            For ($X = 0; $X -le $Body.GetUpperBound(0); $X++) {
                If ($Table[($Position.X + $X), ($Position.Y + $Y)] -and $Body[$X, $Y]) {
                    Return $true
                }
            }
        }
        Return $false
    }

    [void] Move([System.Drawing.Point] $PositionChange, [int[, ]] $TableCoordinates) {
        $PositionChange = [System.Drawing.Point]::new(
            ($this.Position.X + $PositionChange.X), 
            ($this.Position.X + $PositionChange.Y)
        )

        If (!$this.IsColliding($this.Body, $TableCoordinates, $PositionChange)) {
            $this.Position = $PositionChange
        }
    }

    [void] Rotate([bool] $Reverse, [int[, ]] $TableCoordinates) {
        If ($this.Type -ne [ShapeTypes]::Square) {
            [int[, ]] $RotatedBody = [int[, ]]::new(($this.Body.GetUpperBound(1) + 1), ($this.Body.GetUpperBound(1) + 1))

            For ($Y = 0; $Y -lt ($this.Body.GetUpperBound(1) + 1); ++$Y) {
                For ($X = 0; $X -lt ($this.Body.GetUpperBound(1) + 1); ++$X) {
                    If ($Reverse) {
                        $RotatedBody[$Y, $X] = $this.Body[$X, (($this.Body.GetUpperBound(1) + 1) - $Y - 1)]
                    }
                    Else {
                        $RotatedBody[$Y, $X] = $this.Body[(($this.Body.GetUpperBound(1) + 1) - $X - 1), $Y]
                    }
                }   
            }
            If (!$this.IsColliding($RotatedBody, $TableCoordinates, $this.Position)) {
                $this.Body = $RotatedBody
            }
        }
    }

    [void] PrintBody() {
        [console]::WriteLine(
            ('Type: {0}, Color: {1}: Left: {2}, Right: {3} Position: {4}, {5}' -f 
            $this.Type, $this.Color.Name, 
            $this.Moveset.Left, $this.Moveset.Right, 
            $this.Position.X, $this.Position.Y
            )
        )
        
        ForEach ($Y in 0 .. $this.Body.GetUpperBound(1)) {
            [console]::WriteLine(
                (
                    (
                        0 .. $this.Body.GetUpperBound(0) | ForEach-Object { 
                            $this.Body[$_, $Y]
                        }
                    ) -join '-' -replace '0', '-'
                )
            )
        }
    }

    TetrisShape([ShapeTypes] $ShapeName) {
        $this.Color = [System.Drawing.Color]::FromArgb(255, (Get-Random (1 .. 255)), (Get-Random (1 .. 255)), (Get-Random (1 .. 255)))
        $this.Type = $ShapeName
        $this.Body = $this.SetShape([int]$ShapeName)
    }
}

class TetrisBoard {
    [bool] $Debug = $false
    [int32] $BlockSize
    [int32] $Width
    [int32] $Height
    [int[, ]] $Coordinates
    [TetrisShape] $NextShape
    [TetrisShape] $ActiveShape
    [PSCustomObject] $Background = [PSCustomObject] @{
        Burn  = $false
        Color = [System.Drawing.Color]::FromArgb(255, 135, 206, 235)
        Min   = 200
        Max   = 254
    }

    [void] Kill() {
        If ($null -ne $this.ActiveShape) {
            For ($Y = 0; $Y -le $this.ActiveShape.Body.GetUpperBound(1); $Y++) {
                For ($X = 0; $X -le $this.ActiveShape.Body.GetUpperBound(0); $X++) {
                    If ($this.ActiveShape.Body[$X, $Y]) {
                        Try {
                            $this.Coordinates[($this.ActiveShape.Position.X + ($X)), ($this.ActiveShape.Position.Y + $Y)] = 1
                        }
                        Catch { }
                    }
                }
            }
            $this.ActiveShape = $null
        }
    }

    [bool] LostGame() {
        # If the next shape collides with a deadblock - player lost
        If ($null -ne $this.NextShape) {
            Return $this.NextShape.IsColliding($this.NextShape.Body, $this.Coordinates, $this.NextShape.Position)
        }
        Else {
            Return $false
        }
    }

    [void] UpdateBoard() {
        # Check for any lines to be removed, or if player has fucked up enough
    }

    [void] UpdateMoveset() {
        If ($null -ne $this.ActiveShape) {
            # Enable movement to each direction
            $this.ActiveShape.Moveset.Left = $true
            $this.ActiveShape.Moveset.Right = $true
            $this.ActiveShape.Moveset.Down = $true
            For ($Y = 0; $Y -le $this.ActiveShape.Body.GetUpperBound(1); $Y++) {
                For ($X = 0; $X -le $this.ActiveShape.Body.GetUpperBound(0); $X++) {
                    If ($this.ActiveShape.Body[$X, $Y]) {
                        If (
                            # If the left side of the block is blocked, or is out of bounds
                            $this.Coordinates[($this.ActiveShape.Position.X + ($X - 1)), ($this.ActiveShape.Position.Y + $Y)] -or
                            $this.RelativePoint($X, $Y, $this.ActiveShape).X -lt $this.BlockSize
                        ) {
                            $this.ActiveShape.Moveset.Left = $false
                        }
                        If (
                            # If the right side of the block is blocked, or is out of bounds
                            $this.Coordinates[($this.ActiveShape.Position.X + ($X + 1)), ($this.ActiveShape.Position.Y + $Y)] -or
                            $this.RelativePoint($X, $Y, $this.ActiveShape).X -ge (($this.Width * $this.BlockSize) - $this.BlockSize)
                        ) {
                            $this.ActiveShape.Moveset.Right = $false
                        }
                        If (
                            # If the block below is dead, or is out of bounds (Debug mode, invincible execpt oob)
                            (
                                !$this.Debug -and
                                $this.Coordinates[($this.ActiveShape.Position.X + $X), ($this.ActiveShape.Position.Y + ($Y + 1))]
                            ) -or
                            $this.RelativePoint($X, $Y, $this.ActiveShape).Y -ge (($this.Height * $this.BlockSize) - $this.BlockSize)
                        ) {
                            $this.ActiveShape.Moveset.Down = $false
                        }
                    }
                }
            }
            
        }
    }

    [void] NewShape() {
        If ($null -ne $this.NextShape) {
            If ($null -eq $this.ActiveShape) {
                $this.ActiveShape = $this.NextShape
                $this.NextShape = [TetrisShape]::new((Get-Random (1 .. 7)))
                $this.NextShape.Position = [System.Drawing.Point]::new((Get-Random (1 .. ($this.Width - ($this.NextShape.Body.GetUpperBound(0) + 1)))), 0)
            }
        }
        Else {
            $this.NextShape = [TetrisShape]::new((Get-Random (1 .. 7)))
            $this.NextShape.Position = [System.Drawing.Point]::new((Get-Random (1 .. ($this.Width - ($this.NextShape.Body.GetUpperBound(0) + 1)))), 0)
        }
    }

    [System.Drawing.Point] RelativePoint([int]$X, [int]$Y, [TetrisShape] $Shape) {
        Return [System.Drawing.Point]::new(
            (($Shape.Position.X * $this.BlockSize) + ($X * $this.BlockSize)),
            (($Shape.Position.Y * $this.BlockSize) + ($Y * $this.BlockSize))
        )
    }

    [void] AddLines([int] $Lines) {
        1 .. $Lines | ForEach-Object {
            #Write-Host 'Starting adding a new line'
            ForEach ($Y in 1 .. $this.Coordinates.GetUpperBound(1)) {
                #Write-Host ('Loop Y:{0}/{1}' -f $Y, $this.Coordinates.GetUpperBound(1))
                0 .. $this.Coordinates.GetUpperBound(0) | ForEach-Object { 
                    #Write-Host ('Column X:{0}/{1} Y:{2} = X:{3}/{4} Y:{5}' -f $_, $this.Coordinates.GetUpperBound(0), ($Y - 1), $_, $this.Coordinates.GetUpperBound(0), $Y)
                    $this.Coordinates[$_, ($Y - 1)] = $this.Coordinates[$_, $Y] 
                }
            }
            0 .. $this.Coordinates.GetUpperBound(0) | ForEach-Object { 
                #Write-Host ('Set: {0},{1} = 1' -f $_, $this.Coordinates.GetUpperBound(1))
                $this.Coordinates[$_, $this.Coordinates.GetUpperBound(1)] = Get-Random (0 .. 1)
            }
        }
    }

    [void] ClearLines() {
        ForEach ($Y in $this.Coordinates.GetUpperBound(1) .. 0) {
            If (!( -join (0 .. $this.Coordinates.GetUpperBound(0) | ForEach-Object { $this.Coordinates[$_, $Y] })).Contains('0')) {
                # Reset top row
                0 .. $this.Coordinates.GetUpperBound(0) | ForEach-Object { $this.Coordinates[$_, 0] = 0 }
                # Loop, from current full row -> row 1 and set currentrow to the one above
                ForEach ($TempY in $Y .. 1) { 
                    0 .. $this.Coordinates.GetUpperBound(0) | ForEach-Object { 
                        $this.Coordinates[$_, $TempY] = $this.Coordinates[$_, ($TempY - 1)] 
                    } 
                }
            }
        }
    }

    [void] PrintBoard() {
        For ($Y = 0; $Y -le $this.Coordinates.GetUpperBound(1); $Y++) {
            [console]::WriteLine(
                (
                    (
                        0 .. $this.Coordinates.GetUpperBound(0) | ForEach-Object { 
                            $this.Coordinates[$_, $Y]
                        }
                    ) -join '-' -replace '0', '-'
                )
            )
        }
    }

    [System.Drawing.Image] DrawImage() {
        $Buffer = [System.Drawing.Bitmap]::new($this.Width * $this.BlockSize, $this.Height * $this.BlockSize)
        $Graphics = [System.Drawing.Graphics]::FromImage($Buffer)
        # Fill buffer with a white background
        $Graphics.FillRectangle(
            [System.Drawing.SolidBrush]::new($this.Background.Color), 
            [System.Drawing.Rectangle]::new(0, 0, $Buffer.Width, $Buffer.Height)
        )

        If (
            ($this.Background.Burn -and $this.Background.Color.B -ge $this.Background.Max) -or
            (!$this.Background.Burn -and $this.Background.Color.B -lt $this.Background.Min)
        ) { 
            $this.Background.Burn = !$this.Background.Burn
        }
        If ($this.Background.Burn) {
            $this.Background.Color = [System.Drawing.Color]::FromArgb(255, $this.Background.Color.R, $this.Background.Color.G, ($this.Background.Color.B + 1))
        }
        Else {
            $this.Background.Color = [System.Drawing.Color]::FromArgb(255, $this.Background.Color.R, $this.Background.Color.G, ($this.Background.Color.B - 1))
        }
        If ($null -ne $this.NextShape) {
            # Draw NextShape
            For ($Y = 0; $Y -le $this.NextShape.Body.GetUpperBound(1); $Y++) {
                For ($X = 0; $X -le $this.NextShape.Body.GetUpperBound(0); $X++) {
                    If ($this.NextShape.Body[$X, $Y]) {
                        # If this part of the shape body is solid, draw it on the table
                        $Graphics.FillRectangle(
                            [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, ($this.Background.Color.R - 60), ($this.Background.Color.G - 60), ($this.Background.Color.B - 60))), 
                            [System.Drawing.Rectangle]::new(
                                $this.RelativePoint($X, $Y, $this.NextShape).X, $this.RelativePoint($X, $Y, $this.NextShape).Y, 
                                $this.BlockSize, $this.BlockSize
                            )
                        )
                        $Graphics.FillRectangle(
                            [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, ($this.Background.Color.R - 30), ($this.Background.Color.G - 30), ($this.Background.Color.B - 30))), 
                            [System.Drawing.Rectangle]::new(
                                $this.RelativePoint($X, $Y, $this.NextShape).X, $this.RelativePoint($X, $Y, $this.NextShape).Y, 
                                $this.BlockSize - 2, $this.BlockSize - 2
                            )
                        )
                    }
                }
            }
        }

        If ($null -ne $this.ActiveShape) {
            # Draw ActiveShape
            For ($Y = 0; $Y -le $this.ActiveShape.Body.GetUpperBound(1); $Y++) {
                For ($X = 0; $X -le $this.ActiveShape.Body.GetUpperBound(0); $X++) {
                    If ($this.ActiveShape.Body[$X, $Y]) {
                        # If this part of the shape body is solid, draw it on the table
                        $Graphics.FillRectangle(
                            [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Gray), 
                            [System.Drawing.Rectangle]::new(
                                $this.RelativePoint($X, $Y, $this.ActiveShape).X, $this.RelativePoint($X, $Y, $this.ActiveShape).Y, 
                                $this.BlockSize, $this.BlockSize
                            )
                        )
                        $Graphics.FillRectangle(
                            [System.Drawing.SolidBrush]::new($this.ActiveShape.Color), 
                            [System.Drawing.Rectangle]::new(
                                $this.RelativePoint($X, $Y, $this.ActiveShape).X, $this.RelativePoint($X, $Y, $this.ActiveShape).Y, 
                                $this.BlockSize - 2, $this.BlockSize - 2
                            )
                        )
                    }
                }
            }
        }
        
        # Draw DeadBlocks
        For ($Y = 0; $Y -le $this.Coordinates.GetUpperBound(1); $Y++) {
            For ($X = 0; $X -le $this.Coordinates.GetUpperBound(0); $X++) {
                If ($this.Coordinates[$X, $Y]) {
                    # Draw a Gray outline
                    $Graphics.FillRectangle(
                        [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Gray), 
                        [System.Drawing.Rectangle]::new(
                            $X * $this.BlockSize, $Y * $this.BlockSize, 
                            $this.BlockSize, $this.BlockSize
                        )
                    )
                    # Fill rest of the rectangle to give 3d block effect
                    $Graphics.FillRectangle(
                        [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Silver), 
                        [System.Drawing.Rectangle]::new(
                            $X * $this.BlockSize, $Y * $this.BlockSize, 
                            $this.BlockSize - 2, $this.BlockSize - 2
                        )
                    )
                }
            }
        }

        If ($this.Debug) {
            For ($Y = 0; $Y -le $this.Coordinates.GetUpperBound(1); $Y++) {
                For ($X = 0; $X -le $this.Coordinates.GetUpperBound(0); $X++) {
                    If ($this.Coordinates[$X, $Y]) {
                    }
                }
            }
            For ($Y = 0; $Y -le $this.ActiveShape.Body.GetUpperBound(1); $Y++) {
                For ($X = 0; $X -le $this.ActiveShape.Body.GetUpperBound(0); $X++) {
                    If (
                        $this.Coordinates[($this.ActiveShape.Position.X + $X), ($this.ActiveShape.Position.Y + $Y)] -and 
                        $this.ActiveShape.Body[$X, $Y]
                    ) {
                        $Graphics.DrawString( 
                            ('{0},{1}: {2}' -f 
                                ($this.ActiveShape.Position.X + $X), 
                                ($this.ActiveShape.Position.Y + $Y),
                            $this.Coordinates[($this.ActiveShape.Position.X + $X), ($this.ActiveShape.Position.Y + $Y)]
                            ),
                            [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Regular),
                            [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Red),
                            $this.RelativePoint($X, $Y, $this.ActiveShape).X, $this.RelativePoint($X, $Y, $this.ActiveShape).Y
                        )
                    }
                }
            }
            # Draws the ActiveShape Body (5x5 dimensions)
            $Graphics.DrawRectangle(
                [System.Drawing.Pen]::new($this.ActiveShape.Color, 1), 
                [System.Drawing.Rectangle]::new(
                    ($this.ActiveShape.Position.X * $this.BlockSize), ($this.ActiveShape.Position.Y * $this.BlockSize), 
                    (($this.ActiveShape.Body.GetUpperBound(0) + 1) * $this.BlockSize) , (($this.ActiveShape.Body.GetUpperBound(1) + 1) * $this.BlockSize)
                )
            )
            # Draws coordinate of the middle body
            $Graphics.DrawString( ('Type: {0}' -f $this.ActiveShape.Type ), 
                [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Regular),
                [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Red),
                1, 0 * $this.BlockSize
            )
            $Graphics.DrawString( ('Color: {0}' -f $this.ActiveShape.Color.Name ), 
                [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Regular),
                [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Red),
                1, 1 * $this.BlockSize
            )
            $Graphics.DrawString( ('Left: {0}, Right: {1}, Down: {2}' -f $this.ActiveShape.Moveset.Left, $this.ActiveShape.Moveset.Right, $this.ActiveShape.Moveset.Down ), 
                [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Regular),
                [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Red),
                1, 2 * $this.BlockSize
            )
        }
        $Graphics.Dispose()
        return $Buffer
    }

    TetrisBoard($Width, $Height, $BlockSize) {
        $this.Coordinates = [int[, ]]::new($Width, $Height)
        $this.BlockSize = $BlockSize
        $this.Width = $Width
        $this.Height = $Height
        # Generate random rubble at start
        $this.AddLines(4)
    }
}

$Engine = [Hashtable]::Synchronized(@{})
$Engine.Settings = @{
    Block          = @{
        Size = 30
    }
    Board          = @{
        Width  = 11
        Height = 21
    }
    SpeedMs        = 300
    CurrentSpeedMs = 300
    LoopTime       = 100
}
$Engine.TetrisBoard = [TetrisBoard]::new($Engine.Settings.Board.Width, $Engine.Settings.Board.Height, $Engine.Settings.Block.Size)
$Engine.NextFall = [Datetime]::Now.AddMilliseconds($Engine.Settings.CurrentSpeedMs)

$PowerShell = [PowerShell]::Create()
$PowerShell.Runspace = [RunSpaceFactory]::CreateRunspace()
$PowerShell.Runspace.Open()
$PowerShell.Runspace.SessionStateProxy.setVariable('Engine', $Engine)
$IAsyncResult = $PowerShell.AddScript( {
        [void] [System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')
        [void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
        [System.Windows.Forms.Application]::EnableVisualStyles()
        $Engine.Form = [System.Windows.Forms.Form] @{
            Text            = 'PowerShell Tetris'
            ClientSize      = [System.Drawing.Size]::new(
                ($Engine.Settings.Block.Size * $Engine.Settings.Board.Width), 
                ($Engine.Settings.Block.Size * $Engine.Settings.Board.Height)
            )
            Font            = [System.Drawing.Font]::new('Segoe UI', 8.25, [System.Drawing.FontStyle]::Regular)
            FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Fixed3D
            KeyPreview      = $true
            MaximizeBox     = $false
        }
        $Engine.PictureBox = [System.Windows.Forms.PictureBox] @{
            Dock     = [System.Windows.Forms.DockStyle]::Fill
            SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
        }
        $Engine.PictureBox.Add_MouseClick(
            {
                Param(
                    $Object,
                    [System.Windows.Forms.MouseEventArgs] $MouseEventArgs
                )
                $Engine.InstantiateBlock = [System.Drawing.Point]::new(
                    ($MouseEventArgs.X - ($MouseEventArgs.X % $Engine.Settings.Block.Size)) / $Engine.Settings.Block.Size,
                    ($MouseEventArgs.Y - ($MouseEventArgs.Y % $Engine.Settings.Block.Size)) / $Engine.Settings.Block.Size
                )
            }
        )
        $Engine.Form.Add_KeyUp( {
                Param( 
                    $Object,
                    [System.Windows.Forms.KeyEventArgs] $Key 
                )
                If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::Space) {
                    $Engine.Settings.CurrentSpeedMs = $Engine.Settings.SpeedMs
                }
                If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
                    $Engine.SwitchShape = $true
                }
                If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::X -and $Engine.TetrisBoard.Debug) {
                    $Engine.AddLines = Get-Random (1 .. 4)
                }
            }
        )
        $Engine.Form.Add_KeyDown( {
                Param( 
                    $Object,
                    [System.Windows.Forms.KeyEventArgs] $Key 
                )
                If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::Space) {
                    $Engine.Settings.CurrentSpeedMs = $Engine.Settings.SpeedMs / 4
                }
                If ($Engine.TetrisBoard.Debug) {
                    If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::K) {
                        $Engine.TetrisBoard.Kill()
                    }
                    If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::NumPad8) {
                        $Engine.TetrisBoard.ActiveShape.Position = [System.Drawing.Point]::new(
                            $Engine.TetrisBoard.ActiveShape.Position.X,
                            $Engine.TetrisBoard.ActiveShape.Position.Y - 1
                        )
                    }
                    If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::NumPad4) {
                        $Engine.TetrisBoard.ActiveShape.Position = [System.Drawing.Point]::new(
                            $Engine.TetrisBoard.ActiveShape.Position.X - 1,
                            $Engine.TetrisBoard.ActiveShape.Position.Y
                        )
                    }
                    If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::NumPad6) {
                        $Engine.TetrisBoard.ActiveShape.Position = [System.Drawing.Point]::new(
                            $Engine.TetrisBoard.ActiveShape.Position.X + 1,
                            $Engine.TetrisBoard.ActiveShape.Position.Y
                        )
                    }
                    If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::NumPad2) {
                        $Engine.TetrisBoard.ActiveShape.Position = [System.Drawing.Point]::new(
                            $Engine.TetrisBoard.ActiveShape.Position.X,
                            $Engine.TetrisBoard.ActiveShape.Position.Y + 1
                        )
                    }
                    If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::NumPad7) {
                        $Engine.TetrisBoard.ActiveShape.Rotate($false)
                    }
                    If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::NumPad9) {
                        $Engine.TetrisBoard.ActiveShape.Rotate($true)
                    }
                }
                If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::P) {
                    $Engine.Debug = $true
                }
                If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::Left) {
                    $Engine.XMove = [System.Drawing.Point]::new(-1, 0)
                }
                If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::Right) {
                    $Engine.XMove = [System.Drawing.Point]::new(1, 0)
                }
                If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::Up) {
                    $Engine.Rotate = $true
                }
                If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::Down) {
                    $Engine.Rotate = $false
                }
                If ($Key.KeyCode -eq [System.Windows.Forms.Keys]::R) {
                    $Engine.Renew = $true
                }
            }
        )
        $Engine.Form.Controls.Add($Engine.PictureBox)
        $Engine.Form.Add_Resize( { If ($Engine.Dispose) { $Engine.Form.Close() } } )
        $Engine.Form.Add_Load( { $Engine.Form.Activate() })
        $Engine.Form.ShowDialog()
        $Engine.Form.Dispose()
    }
).BeginInvoke()

While (-not $IAsyncResult.IsCompleted) {
    If ($null -ne $Engine.PictureBox) {
        $Time = Measure-Command {
            If ($null -ne $Engine.AddLines -and $Engine.TetrisBoard.Debug) {
                Write-Host ('Adding {0} lines' -f $Engine.AddLines)
                $Engine.TetrisBoard.AddLines($Engine.AddLines)
                $Engine.AddLines = $null
            }
            If ($null -ne $Engine.SwitchShape -and $null -ne $Engine.TetrisBoard.ActiveShape -and $null -ne $Engine.TetrisBoard.NextShape) {
                $TempShape = $Engine.TetrisBoard.ActiveShape
                $Engine.TetrisBoard.ActiveShape = $Engine.TetrisBoard.NextShape
                $Engine.TetrisBoard.NextShape = $TempShape
                $TempShape = $null
                $Engine.SwitchShape = $null
            }
            If ($null -ne $Engine.InstantiateBlock -and $Engine.TetrisBoard.Debug) {
                $Engine.TetrisBoard.Coordinates[$Engine.InstantiateBlock.X, $Engine.InstantiateBlock.Y] = !$Engine.TetrisBoard.Coordinates[$Engine.InstantiateBlock.X, $Engine.InstantiateBlock.Y]
                $Engine.InstantiateBlock = $null
            }
            If ($null -ne $Engine.XMove) {
                $Engine.TetrisBoard.UpdateMoveset()
                If (
                    ($Engine.XMove.X -gt 0 -and $Engine.TetrisBoard.ActiveShape.Moveset.Right) -or
                    ($Engine.XMove.X -lt 0 -and $Engine.TetrisBoard.ActiveShape.Moveset.Left)
                ) {
                    $Engine.TetrisBoard.ActiveShape.Position = [System.Drawing.Point]::new(
                        ($Engine.TetrisBoard.ActiveShape.Position.X + $Engine.XMove.X), 
                        $Engine.TetrisBoard.ActiveShape.Position.Y + $Engine.XMove.Y
                    )
                }
                $Engine.XMove = $null
            }
            If ($null -ne $Engine.Debug) {
                $Engine.TetrisBoard.Debug = !$Engine.TetrisBoard.Debug
                $Engine.Debug = $null
            }
            If ($null -ne $Engine.Renew) {
                $Engine.TetrisBoard.ActiveShape = $null
                $Engine.Renew = $null
            }
            If ($null -ne $Engine.Rotate -and $null -ne $Engine.TetrisBoard.ActiveShape) {
                $Engine.TetrisBoard.UpdateMoveset()
                $Engine.TetrisBoard.ActiveShape.Rotate($Engine.Rotate, $Engine.TetrisBoard.Coordinates)
                $Engine.Rotate = $null
            }
    
            If ([Datetime]::Now -ge $Engine.NextFall -and $null -ne $Engine.TetrisBoard.ActiveShape) {
                $Engine.TetrisBoard.UpdateMoveset()
                If ($Engine.TetrisBoard.ActiveShape.Moveset.Down) {
                    $Engine.TetrisBoard.ActiveShape.Position = [System.Drawing.Point]::new(
                        ($Engine.TetrisBoard.ActiveShape.Position.X), 
                        $Engine.TetrisBoard.ActiveShape.Position.Y + 1
                    )
                }
                Else {
                    $Engine.TetrisBoard.Kill()
                }
                $Engine.NextFall = [Datetime]::Now.AddMilliseconds($Engine.Settings.CurrentSpeedMs)
            }
            If ($Engine.TetrisBoard.LostGame()) {
                $Engine.TetrisBoard = [TetrisBoard]::new($Engine.Settings.Board.Width, $Engine.Settings.Board.Height, $Engine.Settings.Block.Size)
            }
            If ($null -eq $Engine.TetrisBoard.ActiveShape) {
                $Engine.TetrisBoard.NewShape()
            }
            $Engine.TetrisBoard.UpdateMoveset()
            $Engine.TetrisBoard.ClearLines()
            $Engine.PictureBox.Image = $Engine.TetrisBoard.DrawImage()
        }
        If ($Time.TotalMilliseconds -lt $Engine.Settings.LoopTime) {
            [System.Threading.Thread]::Sleep(($Engine.Settings.LoopTime - $Time.TotalMilliseconds))
        }
    }
}