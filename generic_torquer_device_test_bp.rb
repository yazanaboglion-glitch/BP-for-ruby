require 'cosmos'
require 'cosmos/script'
require "generic_torquer_lib.rb"
require 'bp_lib' # הספרייה שלך שמכילה את run_bprogram

GENERIC_TORQUER_CMD_SLEEP = 0.25
GENERIC_TORQUER_RESPONSE_TIMEOUT = 5

def get_generic_torquer_hk()
    sleep(GENERIC_TORQUER_CMD_SLEEP)
    cmd("GENERIC_TORQUER GENERIC_TORQUER_REQ_HK_CC")
    wait_check_packet("GENERIC_TORQUER", "GENERIC_TORQUER_HK_TLM_T", 1, GENERIC_TORQUER_RESPONSE_TIMEOUT)
    sleep(GENERIC_TORQUER_CMD_SLEEP)

end

# --- הפונקציה המבצעת (Actuator) ---
# כאן נמצאת הלוגיקה של שורות 28-29 וההבדל ביניהן
def actuate(e)
  if["disable"].include?(e)
        cmd("GENERIC_TORQUER GENERIC_TORQUER_DISABLE_CC")
  end
  # קבוצת אירועי הפעלה (בין אם תקינים או לא)
  if ["ewe"].include?(e)
    cmd_cnt = tlm("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT")
    cmd_err_cnt = tlm("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT")
    cmd("GENERIC_TORQUER GENERIC_TORQUER_ENABLE_CC")
    get_generic_torquer_hk()
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT == #{cmd_cnt}")
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT == #{cmd_err_cnt+1}")
  end

  if ["ewd"].include?(e)
    cmd_cnt = tlm("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT")
    cmd_err_cnt = tlm("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT")
    cmd("GENERIC_TORQUER GENERIC_TORQUER_ENABLE_CC")
    get_generic_torquer_hk()
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT == #{cmd_cnt+1}")
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT == #{cmd_err_cnt}")  
  end
  


  # קבוצת אירועי כיבוי (בין אם תקינים או לא)
  if ["dwd"].include?(e)
    cmd_cnt = tlm("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT")
    cmd_err_cnt = tlm("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT")
    cmd("GENERIC_TORQUER GENERIC_TORQUER_DISABLE_CC")
    get_generic_torquer_hk()
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT == #{cmd_cnt}")
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT == #{cmd_err_cnt+1}")

  end
  if ["dwe"].include?(e)
    cmd_cnt = tlm("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT")
    cmd_err_cnt = tlm("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT")
    cmd("GENERIC_TORQUER GENERIC_TORQUER_DISABLE_CC")
    get_generic_torquer_hk()
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_COUNT == #{cmd_cnt+1}")
    check("GENERIC_TORQUER GENERIC_TORQUER_HK_TLM_T CMD_ERR_COUNT == #{cmd_err_cnt}")
  end


  
end

# --- הגדרת 5 ה-BThreads (הפייברים) ---

# 1. אירוע: Disable when already Disable (dwd)
# מנסה לכבות כשהמערכת כבר כבויה
fiber_1 = Fiber.new do
  Fiber.yield({:request => "disable" }) 
  loop { Fiber.yield({:request => ["dwd", "dwe" , "ewd" , "ewe"] }) }
end

# 5. אירוע: HK Thread (הלוגיקה המקורית ששלחת)
# זהו ה-State Machine שקובע מה הסטטוס הנוכחי וחוסם פעולות סותרות
hk_thread = Fiber.new do
  loop do
    # מצב: כבוי. מחכה להדלקה (ewd).
    # חוסם: הדלקה כפולה (ewe) וכיבוי מתוך דלוק (dwe - כי אנחנו כבויים כרגע)
    # הערה: הוא לא חוסם dwd, ולכן fiber_1 יכול לרוץ במצב הזה (שגיאת יתירות)
    Fiber.yield({ :wait => "ewd", :block => ["ewe", "dwe"] })

    # מצב: דלוק. מחכה לכיבוי (dwe).
    # חוסם: הדלקה מתוך כבוי (ewd - כי אנחנו דלוקים) וכיבוי כפול (dwd)
    # הערה: הוא לא חוסם ewe, ולכן fiber_2 יכול לרוץ במצב הזה (שגיאת יתירות)
    Fiber.yield({ :wait => "dwe", :block => ["ewd", "dwd"] })
  end
end


# --- הרצה ---

# איסוף 5 הפייברים
bthreads = [fiber_1 , hk_thread]

# הרצת התוכנית בעזרת הספרייה שלך
# הספרייה תבצע את הרנדומיזציה (שורה 26 בקוד המקורי של הספרייה)
# ופונקציית actuate תבצע את הפקודות (שורות 28-29)
run_bprogram(bthreads, method(:actuate), steps=20)
