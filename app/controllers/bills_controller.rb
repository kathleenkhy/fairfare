class BillsController < ApplicationController
  skip_before_action :authenticate_user!

  # def show
  #   @bill = Bill.find(params[:id])
  #   data = @bill.receipt_data

  #   items = []
  #   items << Item.new(...)

  #   puts items

  #   render json: { data: } # this is to show the json code on the webpage in local
  # remember that price will need to be converted to cents
  # transfer this to the items controller #index method instead and list out the items on the html.erb file
  # end

  def receipt
    @split = Split.find(params[:split_id])
  end

  def upload
    @bill = Bill.create(split_id: params[:split_id])
    @bill.photo = params[:image]

    if @bill.save
      # schedule a background job
      ParseReceiptJob.perform_later(@bill)

      redirect_to edit_split_bill_path(@bill.split, @bill)
      # check sidekiq background jobs on what to do when the json is obtained from ocr
    else
      raise
    end
  end

  def select
    @split = Split.find(params[:split_id])
  end

  def index
    @bills = Bill.all
  end

  def show
    @bill = Bill.find(params[:id])
  end

  def new
    @split = Split.find(params[:split_id])
    @bill = Bill.new
    @bill.items.build
  end

  def create

    @split = Split.find(params[:split_id])
    converted_params = bill_params

    # i suspect we wont be sending price at all via the create action. need to confirm.
    converted_params[:items_attributes].each do |item|
      unless (item[1][:price_in_dollars])
        item[1][:price] = item[1][:price].to_f * 100
      end
    end

    converted_params[:taxes] = converted_params[:taxes].to_f * 100
    converted_params[:discount] = converted_params[:discount].to_f * 100
    converted_params[:service_charge] = converted_params[:service_charge].to_f * 100
    converted_params[:total_amount] = converted_params[:total_amount].to_f * 100

    @bill = Bill.new(converted_params)
    @bill.split = @split

    if @bill.save
      @bill.update_total_bill if @bill.total_amount.nil? || @bill.total_amount.zero?

      redirect_to split_bill_items_path(@split, @bill)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @bill = Bill.find(params[:id])

    if @bill.scraping_data
      render :scraping
    else
      @split = @bill.split
      @bill.items.build
    end
  end

  def update
    # pp params
    @bill = Bill.find(params[:id])
    @bill.update(bill_params)
    @bill.update_total_bill

    respond_to do |format|
      format.html { redirect_to split_bill_items_path(@bill.split, @bill) }
      format.text { render(partial: 'bills/breakdown', formats: :html, locals: { bill: @bill }) }
    end
  end

  # added on 21-09 @ 9.36pm
  def items
    @split = Split.find(params[:split_id])
    @bill = Bill.find(params[:bill_id])
    @items = Item.where(bill_id: @bill.id)

    @items.update(item_params)
    @bill.update_total_bill if @bill.total_amount.nil? || @bill.total_amount.zero?

    redirect_to split_bill_items_path(@split)
  end

  private

  def bill_params
    # params.require(:bill).permit(:merchant, items_attributes: %i[name price quantity])
    params.require(:bill).permit(:total_amount,
      :total_amount_in_dollars,
      :taxes_in_dollars,
      :discount_in_dollars,
      :service_charge_in_dollars,
      :merchant, :date, :discount, :service_charge, :taxes, items_attributes: %i[id name price price_in_dollars quantity])
  end
end
