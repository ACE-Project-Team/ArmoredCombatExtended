
local SurveyDesc = "A Survey is out! We would love to hear your feedback!"
local Surveylink = "https://forms.gle/aowZ32cDkJhE6m9f9"

CreateClientConVar("ace_survey_message", "1", true, false, "Set to 0 to disable the ACE survey message.")
if GetConVar("ace_survey_message"):GetInt() == 0 then return end

hook.Add("CreateMove", "ACE Survey", function(Move)
    if Move:GetButtons() ~= 0 then
        chat.AddText(Color(255, 0, 0), "[ACE] ", Color(255, 0, 0), SurveyDesc)
        chat.AddText(Color(255, 0, 0), "[ACE] ", Color(255, 255, 255), "You can fill our survey here: ", Color(255, 100, 0), Surveylink)
        chat.AddText(Color(255, 0, 0), "[ACE] ", Color(255, 255, 255), "This message can be hidden by writting 'ace_survey_message 0' in console.")
        hook.Remove("CreateMove", "ACE Survey")
    end
end)